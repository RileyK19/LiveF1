//
//  GetLapsTool.swift
//  Redline
//
//  Created by Riley Koo on 9/20/26.
//
import Foundation
import FoundationModels

// MARK: - Arguments

@Generable
struct GetLapsArguments {
    @Guide(description: "Race identifier as the user described it, or 'next'/'last' for upcoming/most recently completed race.", .anyOf(LiveF1Constraints.trackNames + ["next", "last"]))
    var raceQuery: String

    @Guide(description: "Session type. Use Qualifying for pole position questions, Sprint Qualifying for sprint pole. Default to Race if unspecified.", .anyOf(["Race", "Qualifying", "Sprint", "Sprint Qualifying", "Practice 1", "Practice 2", "Practice 3"]))
    var sessionType: String

    @Guide(description: "True ONLY if the user named one or more specific drivers by name. False for general questions like 'who got pole' or 'fastest lap of the race' — false is the default and by far the most common case.")
    var filterToSpecificDrivers: Bool

    @Guide(description: "Driver names exactly as the user wrote them, e.g. ['Verstappen', 'Kimi']. Only used when filterToSpecificDrivers is true — leave empty otherwise. Do not resolve these to numbers yourself — this tool does that internally.")
    var driverNames: [String]

    @Guide(description: "How many of the fastest laps to return. 1 = the single fastest lap (e.g. 'pole', 'fastest lap'), 3 = the top three, 0 = every lap (ONLY valid when specific drivers are named, e.g. 'show me all of Kimi's laps').", .range(0...20))
    var fastestCount: Int

    @Guide(description: "True to return each driver's single best lap, ranked (e.g. 'top 10 in qualifying', 'qualifying order'). False for everything else, including 'pole' and 'fastest lap of the race'.")
    var bestLapPerDriver: Bool
}

// MARK: - Result

@Generable
struct LapSummary: Sendable {
    var driverNumber: Int
    var driverName: String
    var lapNumber: Int
    @Guide(description: "Lap time formatted m:ss.SSS — read this out as-is, never reformat.")
    var lapTime: String
    var lapTimeSeconds: Double
    @Guide(description: "Gap to the fastest lap in this result, e.g. '+0.123'. '—' for the fastest.")
    var gapToFastest: String
}

@Generable
struct GetLapsResult: Sendable {
    var success: Bool
    var errorMessage: String?
    var raceName: String?
    var sessionType: String?
    var totalLapsMatched: Int
    @Guide(description: "Fastest laps first. May be a subset — see note.")
    var laps: [LapSummary]
    var note: String?
    var unmatchedDriverNames: [String]
}

enum GetLapsError: LocalizedError {
    case noLapData

    var errorDescription: String? {
        switch self {
        case .noLapData: return "No timed laps available for that session yet."
        }
    }
}

// MARK: - Tool

struct GetLapsTool: Tool {
    let name = "getLaps"
    let description = "Loads the given session and returns lap times: the fastest lap (pole in Qualifying), the top N laps, each driver's best lap ranked, or every lap for named drivers. Resolves driver names internally, so pass names as the user wrote them, never numbers. Does not require loadRaceForStrategy — this tool loads its own data. Set filterToSpecificDrivers to true only when the user named specific drivers."

    let onResult: @Sendable ([LapSummary], GetLapsResult) -> Void

    /// The model only sees this many laps; the card gets everything.
    private static let modelLapLimit = 8

    func call(arguments: GetLapsArguments) async throws -> GetLapsResult {
        let session: F1PredictorSession
        do {
            session = try await RaceSessionResolver.resolve(
                raceQuery: arguments.raceQuery,
                sessionType: arguments.sessionType
            )
        } catch LoadRaceForStrategyError.noMatch {
            return failure("No \(arguments.sessionType) session found for \(arguments.raceQuery) this season.",
                           unmatched: [])
        }
        let key = "\(session.sessionKey)"

        // Kick off the lap fetch and the driver lookup in parallel.
        async let rawLaps = F1LapParser.fetchLive(sessionKey: key)
        let driverInfo = (try? await F1PredictorDriverParser.fetch(sessionKey: key)) ?? []
        let allLaps = try await rawLaps

        let nameByNumber = Dictionary(
            driverInfo.map { ($0.driverNumber, $0.fullName) },
            uniquingKeysWith: { first, _ in first }
        )

        // Only laps that actually have a time (out laps, lap 1, red-flagged laps are nil).
        var pool = allLaps.filter { $0.lapDuration != nil }

        // Driver filtering — same matching approach as the race pace tool.
        var unmatched: [String] = []
        let hasDriverFilter = arguments.filterToSpecificDrivers && !arguments.driverNames.isEmpty

        if hasDriverFilter {
            var matchedNumbers: Set<Int> = []
            for query in arguments.driverNames {
                let q = query.trimmingCharacters(in: .whitespaces).lowercased()
                guard !q.isEmpty else { continue }
                if let hit = nameByNumber.first(where: {
                    $0.value.lowercased().contains(q) || q.contains($0.value.lowercased())
                }) {
                    matchedNumbers.insert(hit.key)
                } else {
                    unmatched.append(query)
                }
            }

            guard !matchedNumbers.isEmpty else {
                let known = nameByNumber.values.sorted().joined(separator: ", ")
                return failure("None of \(arguments.driverNames) matched a driver in this session. Known drivers: \(known).",
                               unmatched: unmatched)
            }
            pool = pool.filter { matchedNumbers.contains($0.driverNumber) }
        }

        guard !pool.isEmpty else { throw GetLapsError.noLapData }

        // Selection
        let count = arguments.fastestCount
        let selected: [F1Lap]

        if arguments.bestLapPerDriver {
            let ranked = await Array(pool.fastestLapPerDriver.values).sortedByLapTime
            selected = count > 0 ? Array(ranked.prefix(count)) : ranked
        } else if count > 0 {
            selected = await Array(pool.sortedByLapTime.prefix(count))
        } else {
            // "All laps" — only sensible for specific drivers, otherwise it's the whole field.
            guard hasDriverFilter else {
                return failure("Returning every lap for the whole field is too much. Ask the user to name a driver, or ask for the fastest N laps instead.",
                               unmatched: unmatched)
            }
            selected = pool.sorted {
                ($0.driverNumber, $0.lapNumber) < ($1.driverNumber, $1.lapNumber)
            }
        }

        guard let reference = selected.compactMap(\.lapDuration).min() else {
            throw GetLapsError.noLapData
        }

        let summaries: [LapSummary] = selected.compactMap { lap in
            guard let t = lap.lapDuration else { return nil }
            let gap = t - reference
            return LapSummary(
                driverNumber: lap.driverNumber,
                driverName: nameByNumber[lap.driverNumber] ?? "#\(lap.driverNumber)",
                lapNumber: lap.lapNumber,
                lapTime: lap.formattedLapTime,
                lapTimeSeconds: t,
                gapToFastest: gap < 0.0005 ? "—" : String(format: "+%.3f", gap)
            )
        }

        // The model gets the fastest few; the card gets the full, display-ordered list.
        let forModel = Array(summaries.sorted { $0.lapTimeSeconds < $1.lapTimeSeconds }
            .prefix(Self.modelLapLimit))
        let truncated = summaries.count > forModel.count

        let result = GetLapsResult(
            success: true,
            errorMessage: nil,
            raceName: session.circuitShortName,
            sessionType: arguments.sessionType,
            totalLapsMatched: summaries.count,
            laps: forModel,
            note: truncated
                ? "Showing the fastest \(forModel.count) of \(summaries.count) laps. The full list is displayed to the user in a card — summarize, don't list them all."
                : nil,
            unmatchedDriverNames: unmatched
        )
        onResult(summaries, result)
        return result
    }

    private func failure(_ message: String, unmatched: [String]) -> GetLapsResult {
        GetLapsResult(
            success: false,
            errorMessage: message,
            raceName: nil,
            sessionType: nil,
            totalLapsMatched: 0,
            laps: [],
            note: nil,
            unmatchedDriverNames: unmatched
        )
    }
}
