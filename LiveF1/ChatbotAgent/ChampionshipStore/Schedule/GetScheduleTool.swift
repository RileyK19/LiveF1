//
//  GetScheduleTool.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//

import Foundation
import FoundationModels

@Generable
struct GetScheduleArguments {
    @Guide(description: "Race name or circuit/location to get the schedule for. Leave empty if asked for the next upcoming race weekend.")
    var raceQuery: String?
}

@Generable
struct SessionEntry: Sendable {
    var name: String
    var formattedDateTime: String
    var isPast: Bool
}

@Generable
struct GetScheduleResult: Sendable {
    var raceName: String
    var round: String
    var circuitName: String
    var locality: String
    var country: String
    var formattedDate: String
    var countdown: String?
    var sessions: [SessionEntry]
}

enum GetScheduleError: Error {
    case raceNotFound
}

struct GetScheduleTool: Tool {
    let name = "getSchedule"
    let description = "Returns the full session schedule (FP1–FP3, Qualifying, Sprint if applicable, and the Race) for a race weekend — the next upcoming weekend by default, or a specific round if given a round number. Only for schedule/session-timing questions ('when is the next race', 'what time is qualifying')"
    
    let store: ChampionshipDataStore
    let onResult: @Sendable (GetScheduleArguments, GetScheduleResult) -> Void

    func call(arguments: GetScheduleArguments) async throws -> GetScheduleResult {
        await store.fetchAllIfNeeded()
        
        let race: ChampionshipRace? = await MainActor.run {
            if let query = arguments.raceQuery?.lowercased(), !query.isEmpty,
                query != "next" {
                return store.races.first {
                    $0.raceName.lowercased().contains(query) ||
                    $0.circuit.circuitName.lowercased().contains(query) ||
                    $0.circuit.location.locality.lowercased().contains(query) ||
                    $0.circuit.location.country.lowercased().contains(query)
                }
            }
            return store.nextRace
        }
        guard let race else { throw GetScheduleError.raceNotFound }
        
        let countdown = await MainActor.run { race.isNext ? store.nextRaceCountdown : nil }

        let sessions = race.allSessions.map {
            SessionEntry(name: $0.name, formattedDateTime: $0.session.formattedDateTime, isPast: $0.session.isPast)
        }

        let result = GetScheduleResult(
            raceName: race.raceName,
            round: race.round,
            circuitName: race.circuit.circuitName,
            locality: race.circuit.location.locality,
            country: race.circuit.location.country,
            formattedDate: race.formattedDate,
            countdown: countdown,
            sessions: sessions
        )
        onResult(arguments, result)
        return result
    }
}
