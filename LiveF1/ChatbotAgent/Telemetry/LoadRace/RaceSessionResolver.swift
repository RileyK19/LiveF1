//
//  RaceSessionResolver.swift
//  Redline
//
//  Created by Riley Koo on 9/18/26.
//

import Foundation

enum RaceSessionResolver {
    static func resolve(raceQuery: String, sessionType rawSessionType: String) async throws -> F1PredictorSession {
        let sessionType = rawSessionType.isEmpty ? "Race" : rawSessionType
        let allSessions = try await F1PredictorSessionParser.fetchRaces(year: 2026, sessionType: sessionType)
        let query = raceQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let matched: F1PredictorSession?
        switch query {
        case "next", "next race", "upcoming":
            matched = allSessions.upcoming.sortedByDate.first
        case "last", "last race", "previous", "most recent":
            matched = allSessions.completed.sortedByDate.last
        default:
            matched = allSessions.first { $0.circuitShortName.lowercased() == query }
        }

        guard let session = matched else {
            throw LoadRaceForStrategyError.noMatch(raceQuery)
        }
        return session
    }
}
