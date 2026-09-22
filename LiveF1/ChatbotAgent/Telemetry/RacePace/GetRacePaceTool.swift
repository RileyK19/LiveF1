//
//  GetRacePaceTool.swift
//  Redline
//
//  Created by Riley Koo on 9/17/26.
//

import Foundation
import FoundationModels
import Combine

@Generable
struct GetRacePaceArguments {
    @Guide(description: "Race identifier as the user described it, or 'next'/'last' for upcoming/most recently completed race.", .anyOf(LiveF1Constraints.trackNames + ["next", "last"]))
    var raceQuery: String

    @Guide(description: "Session type: Race, Qualifying, Sprint, FP1, FP2, or FP3. Default to Race if unspecified.")
    var sessionType: String

    @Guide(description: "True ONLY if the user named one or more specific drivers by name. False for general questions like 'who was fastest' or 'show me the race pace' — false is the default and by far the most common case.")
    var filterToSpecificDrivers: Bool

    @Guide(description: "Driver names exactly as the user wrote them, e.g. ['Verstappen', 'Hadjar']. Only used when filterToSpecificDrivers is true — leave empty otherwise, it will be ignored either way. Do not resolve these to numbers yourself — this tool does that internally.")
    var driverNames: [String]

    @Guide(description: "True for recent form only — a rolling window over the last 5 laps, for questions like 'who's quickest right now' or 'how has #16 been recently'. False for the whole race so far, for questions like 'who had the best race pace'.")
    var recentFormOnly: Bool
}

@Generable
struct DriverPaceSummary: Sendable {
    var driverNumber: Int
    var driverName: String
    @Guide(description: "This driver's median lap time as a percentage of the fastest driver's median — 100 means fastest, 102.5 means 2.5% off the pace.")
    var medianPercentOffFastest: Double
    var medianLapTimeSeconds: Double
    var isFastest: Bool
}

@Generable
struct GetRacePaceResult: Sendable {
    var success: Bool
    var errorMessage: String?
    var fastestLapTimeSeconds: Double?
    var lapsConsidered: String?
    var raceName: String?
    var unmatchedDriverNames: [String]
    var summaries: [DriverPaceSummary]
}

enum GetRacePaceError: LocalizedError {
    case insufficientData

    var errorDescription: String? {
        switch self {
        case .insufficientData: return "Not enough clean lap data yet to compute race pace."
        }
    }
}

@MainActor
struct GetRacePaceTool: Tool {
    let name = "getRacePace"
    let description = "Loads the given race (same identifiers as loadRaceForStrategy) and computes each driver's race pace — median lap time relative to the fastest driver — across the whole race so far, or a recent 5-lap rolling window. Resolves driver names internally, so pass names as the user wrote them, never numbers. Does not require loadRaceForStrategy to be called first — this tool loads its own race. Set filterToSpecificDrivers to true only when the user named specific drivers."

    let sessionStore: CurrentSessionStore
    let onResult: @Sendable ([DriverPaceStats], [DriverPaceStats], GetRacePaceResult) -> Void

    func call(arguments: GetRacePaceArguments) async throws -> GetRacePaceResult {
        print(arguments)
        let session = try await RaceSessionResolver.resolve(
            raceQuery: arguments.raceQuery,
            sessionType: arguments.sessionType
        )
        let vm = await sessionStore.loadAndWait(session: session)

        let driverInfo = (try? await F1PredictorDriverParser.fetch(sessionKey: "\(session.sessionKey)")) ?? []
        let nameByNumber = Dictionary(uniqueKeysWithValues: driverInfo.map { ($0.driverNumber, $0.fullName) })

        let stats: [DriverPaceStats]
        let fastestLapTime: Double
        let lapsConsidered: String

        if arguments.recentFormOnly {
            guard let recent = RacePaceCalculator.recentStats(from: vm.laps, windowSize: 5) else {
                throw GetRacePaceError.insufficientData
            }
            stats = recent.stats
            fastestLapTime = recent.fastestLapTime
            lapsConsidered = "last 5 laps (through lap \(recent.asOfLap))"
        } else {
            let overall = RacePaceCalculator.overallStats(from: vm.laps)
            guard !overall.stats.isEmpty else {
                throw GetRacePaceError.insufficientData
            }
            stats = overall.stats
            fastestLapTime = overall.fastestLapTime
            lapsConsidered = "the whole race so far"
        }

        // sorted ascending by median — first entry is the true fastest, computed
        // before any filtering so isFastest still reflects the full field.
        let globalFastestDriver = stats.first?.driverNumber

        // Gate on the boolean, not on the array being empty — small models are far
        // more reliable at answering a yes/no question than at remembering to emit [].
        var unmatched: [String] = []
        let filtered: [DriverPaceStats]

        if !arguments.filterToSpecificDrivers || arguments.driverNames.isEmpty {
            filtered = stats
        } else {
            var matchedNumbers: [Int] = []
            for query in arguments.driverNames {
                let q = query.trimmingCharacters(in: .whitespaces).lowercased()
                guard !q.isEmpty else { continue }
                if let hit = nameByNumber.first(where: {
                    $0.value.lowercased().contains(q) || q.contains($0.value.lowercased())
                }) {
                    matchedNumbers.append(hit.key)
                } else {
                    unmatched.append(query)
                }
            }
            let matched = stats.filter { matchedNumbers.contains($0.driverNumber) }

            guard !matched.isEmpty else {
                let known = nameByNumber.values.sorted().joined(separator: ", ")
                return GetRacePaceResult(
                    success: false,
                    errorMessage: "None of \(arguments.driverNames) matched a driver in this session. Known drivers: \(known).",
                    fastestLapTimeSeconds: nil,
                    lapsConsidered: nil,
                    raceName: nil,
                    unmatchedDriverNames: unmatched,
                    summaries: []
                )
            }
            filtered = matched
        }

        let summaries = filtered.map { stat in
            DriverPaceSummary(
                driverNumber: stat.driverNumber,
                driverName: nameByNumber[stat.driverNumber] ?? "#\(stat.driverNumber)",
                medianPercentOffFastest: stat.median,
                medianLapTimeSeconds: fastestLapTime * (stat.median / 100),
                isFastest: stat.driverNumber == globalFastestDriver
            )
        }

        let result = GetRacePaceResult(
            success: true,
            errorMessage: nil,
            fastestLapTimeSeconds: fastestLapTime,
            lapsConsidered: lapsConsidered,
            raceName: session.circuitShortName,
            unmatchedDriverNames: unmatched,
            summaries: summaries
        )
        onResult(filtered, stats, result)
        return result
    }
}

//
//import Foundation
//import FoundationModels
//import Combine
//
//@Generable
//struct GetRacePaceArguments {
//    @Guide(description: "Driver numbers to focus on. Give an empty array to include every driver in the session if the user doesn't specify any drivers in the prompt. If you are unsure which drivers to specify, give an empty array, eg: []. Resolve names against driverRoster from loadRaceForStrategy — never guess a number. Only populate the array if user directly specifies drivers, otherwise use an empty array")
//    var driverNumbers: [Int]
//
//    @Guide(description: "True for recent form only — a rolling window over the last 5 laps.False for the whole race so far.")
//    var recentFormOnly: Bool
//
//    @Guide(description: "Required. The exact track name you just passed to loadRaceForStrategy this turn — copy it verbatim. You have no way to know what race is currently loaded without having just called loadRaceForStrategy, so this must always come from that call, never from memory.")
//    var trackName: String
//}
//
//@Generable
//struct DriverPaceSummary: Sendable {
//    var driverNumber: Int
//    @Guide(description: "This driver's median lap time as a percentage of the fastest driver's median — 100 means fastest, 102.5 means 2.5% off the pace.")
//    var medianPercentOffFastest: Double
//    var medianLapTimeSeconds: Double
//    var isFastest: Bool
//}
//
//@Generable
//struct GetRacePaceResult: Sendable {
//    var success: Bool
//    var errorMessage: String?
//    var fastestLapTimeSeconds: Double?
//    var lapsConsidered: String?
//    var summaries: [DriverPaceSummary]
//}
//
//enum GetRacePaceError: LocalizedError {
//    case noRaceLoaded
//    case insufficientData
//    case wrongRaceLoaded(loaded: String, requested: String)
//
//    var errorDescription: String? {
//        switch self {
//        case .noRaceLoaded: return "No race is loaded yet. Call loadRaceForStrategy first."
//        case .insufficientData: return "Not enough clean lap data yet to compute race pace."
//        case .wrongRaceLoaded(let loaded, let requested):
//            return "The currently loaded race is \(loaded), but this question is about \(requested). Call loadRaceForStrategy with \(requested) first, then call getRacePace again."
//        }
//    }
//}
//
//@MainActor
//struct GetRacePaceTool: Tool {
//    let name = "getRacePace"
//    let description = "Computes each driver's race pace — median lap time relative to the fastest driver — either across the whole race so far or a recent 5-lap rolling window. Always call loadRaceForStrategy first, in this same turn, and pass its track name into trackName — this tool will reject calls where trackName doesn't match the currently loaded race. Only pass a non empty array if the user directly specifies drivers"
//
//    let sessionStore: CurrentSessionStore
//    let onResult: @Sendable ([DriverPaceStats], [DriverPaceStats], GetRacePaceResult) -> Void
//
//    func call(arguments: GetRacePaceArguments) async throws -> GetRacePaceResult {
//        print(arguments)
//        guard let vm = sessionStore.raceViewModel else {
//            throw GetRacePaceError.noRaceLoaded
//        }
//
//        let loaded = vm.session.circuitShortName
//        let matches = loaded.localizedCaseInsensitiveContains(arguments.trackName)
//            || arguments.trackName.localizedCaseInsensitiveContains(loaded)
//        guard matches else {
//            throw GetRacePaceError.wrongRaceLoaded(loaded: loaded, requested: arguments.trackName)
//        }
//
//        let stats: [DriverPaceStats]
//        let fastestLapTime: Double
//        let lapsConsidered: String
//
//        if arguments.recentFormOnly {
//            guard let recent = RacePaceCalculator.recentStats(from: vm.laps, windowSize: 5) else {
//                throw GetRacePaceError.insufficientData
//            }
//            stats = recent.stats
//            fastestLapTime = recent.fastestLapTime
//            lapsConsidered = "last 5 laps (through lap \(recent.asOfLap))"
//        } else {
//            let overall = RacePaceCalculator.overallStats(from: vm.laps)
//            guard !overall.stats.isEmpty else {
//                throw GetRacePaceError.insufficientData
//            }
//            stats = overall.stats
//            fastestLapTime = overall.fastestLapTime
//            lapsConsidered = "the whole race so far"
//        }
//
//        // sorted ascending by median already, so the first entry is the true fastest —
//        // compute this BEFORE filtering so isFastest still reflects the full field.
//        let globalFastestDriver = stats.first?.driverNumber
//
//        let filtered: [DriverPaceStats]
//        if arguments.driverNumbers.isEmpty {
//            filtered = stats
//        } else {
//            filtered = stats.filter { arguments.driverNumbers.contains($0.driverNumber) }
//            guard !filtered.isEmpty else {
//                let available = stats.map(\.driverNumber).sorted()
//                return GetRacePaceResult(
//                    success: false,
//                    errorMessage: "None of \(arguments.driverNumbers) have race pace data. Drivers with data: \(available). Fix and call getRacePace again.",
//                    fastestLapTimeSeconds: nil,
//                    lapsConsidered: nil,
//                    summaries: []
//                )
//            }
//        }
//
//        let summaries = filtered.map { stat in
//            DriverPaceSummary(
//                driverNumber: stat.driverNumber,
//                medianPercentOffFastest: stat.median,
//                medianLapTimeSeconds: fastestLapTime * (stat.median / 100),
//                isFastest: stat.driverNumber == globalFastestDriver
//            )
//        }
//
//        let result = GetRacePaceResult(
//            success: true,
//            errorMessage: nil,
//            fastestLapTimeSeconds: fastestLapTime,
//            lapsConsidered: lapsConsidered,
//            summaries: summaries
//        )
//        onResult(filtered, stats, result)
//        return result
//    }
//}
