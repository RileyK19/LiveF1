//
//  LoadRaceForStrategyTool.swift
//  Redline
//
//  Created by Riley Koo on 9/6/26.
//

import Foundation
import FoundationModels

@Generable
struct LoadRaceForStrategyArguments {
    @Guide(description: "Race identifier as the user described it, or 'next'/'last' for upcoming/most recently completed race.", .anyOf(LiveF1Constraints.trackNames + ["next", "last"]))
    var raceQuery: String

    @Guide(description: "Session type to load: Race, Qualifying, Sprint, FP1, FP2, or FP3. Default to Race if unspecified.")
    var sessionType: String
}

@Generable
struct LoadRaceForStrategyResult: Sendable {
    var raceName: String
    var sessionName: String
    var lapsLoaded: Int
    var totalLaps: Int?
    var driverRoster: [String]
}

enum LoadRaceForStrategyError: LocalizedError {
    case noMatch(String)
    case ambiguous([F1PredictorSession])

    var errorDescription: String? {
        switch self {
        case .noMatch(let q): return "No race matching '\(q)' was found."
        case .ambiguous: return "Multiple races matched — please be more specific (e.g. include the year or circuit name)."
        }
    }
}

@MainActor
struct LoadRaceForStrategyTool: Tool {
    let name = "loadRaceForStrategy"
    let description = "Loads race session data (laps, stints) needed for strategy analysis. Call this first for any strategy question. Returns availableDrivers — you MUST then call selectDriverForStrategy with a number from that list before evaluating any strategy."

    let sessionStore: CurrentSessionStore

    func call(arguments: LoadRaceForStrategyArguments) async throws -> LoadRaceForStrategyResult {
        let session = try await RaceSessionResolver.resolve(
            raceQuery: arguments.raceQuery,
            sessionType: arguments.sessionType
        )

        let vm = await sessionStore.loadAndWait(session: session)
        let driverInfo = (try? await F1PredictorDriverParser.fetch(sessionKey: "\(session.sessionKey)")) ?? []
        let nameByNumber = Dictionary(uniqueKeysWithValues: driverInfo.map { ($0.driverNumber, $0.fullName) })

        let roster = vm.drivers.map { number in
            nameByNumber[number].map { "\(number): \($0)" } ?? "\(number)"
        }

        return LoadRaceForStrategyResult(
            raceName: session.circuitShortName,
            sessionName: session.sessionName,
            lapsLoaded: vm.laps.count,
            totalLaps: vm.laps.map { $0.lapNumber }.max(),
            driverRoster: roster
        )
    }
    
//    func call(arguments: LoadRaceForStrategyArguments) async throws -> LoadRaceForStrategyResult {
//        print("\nRace\n\(arguments)\n")
//        let sessionType = arguments.sessionType.isEmpty ? "Race" : arguments.sessionType
//        let allSessions = try await F1PredictorSessionParser.fetchRaces(year: 2026, sessionType: sessionType)
//        let query = arguments.raceQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
//
//        let matched: F1PredictorSession?
//        switch query {
//        case "next", "next race", "upcoming":
//            matched = allSessions.upcoming.sortedByDate.first
//        case "last", "last race", "previous", "most recent":
//            matched = allSessions.completed.sortedByDate.last
//        default:
//            // Since raceQuery is now constrained to real circuit names via .anyOf,
//            // this can be a direct match instead of fuzzy prefix matching.
//            matched = allSessions.first { $0.circuitShortName.lowercased() == query }
//        }
//
//        guard let session = matched else {
//            throw LoadRaceForStrategyError.noMatch(arguments.raceQuery)
//        }
//
//        let vm = await sessionStore.loadAndWait(session: session)
//        let driverInfo = (try? await F1PredictorDriverParser.fetch(sessionKey: "\(session.sessionKey)")) ?? []
//        let nameByNumber = Dictionary(uniqueKeysWithValues: driverInfo.map { ($0.driverNumber, $0.fullName) })
//
//        let roster = vm.drivers.map { number in
//            if let name = nameByNumber[number] {
//                return "\(number): \(name)"
//            }
//            return "\(number)"
//        }
////        print("ROSTER: \(roster)")
//        
//        return LoadRaceForStrategyResult(
//            raceName: session.circuitShortName,
//            sessionName: session.sessionName,
//            lapsLoaded: vm.laps.count,
//            totalLaps: vm.laps.map { $0.lapNumber }.max(),
//            driverRoster: roster
//        )
//    }
}
