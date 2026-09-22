//
//  SessionSelectTool.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//

import Foundation
import FoundationModels

@Generable
enum SessionWeekendScope: String {
    case next    // only the upcoming weekend
    case season  // search across the whole season
}

@Generable
enum SessionTypeScope: String {
    case raceOnly       // just Grand Prix races
    case raceAndSprint  // races + sprint races
    case all            // every session incl. practice/qualifying
}

@Generable
struct SelectSessionArguments {
    @Guide(description: "Whether to only consider the next upcoming race weekend, or search across the whole season")
    var weekendScope: SessionWeekendScope

    @Guide(description: "Which session types to offer as choices: races only, races and sprints, or all session types")
    var sessionTypeScope: SessionTypeScope
}

@Generable
struct SelectSessionResult: Sendable {
    var selected: SessionOption
}

enum SelectSessionError: Error {
    case noSessionsFound
}

struct SelectSessionTool: Tool {
    let name = "selectSession"
    let description = "Presents the user with a list of race weekend sessions to choose from and waits for their pick. Only use this if there are genuinely multiple races or sessions that could match the question — do not use it for single-answer questions like 'the next race.'"

    let store: ChampionshipDataStore
    let coordinator: SessionSelectionCoordinator

    func call(arguments: SelectSessionArguments) async throws -> SelectSessionResult {
        let races: [ChampionshipRace] = await MainActor.run {
            switch arguments.weekendScope {
            case .next:
                return store.nextRace.map { [$0] } ?? []
            case .season:
                return store.races
            }
        }

        var options: [SessionOption] = []
        for race in races {
            let sessions: [(name: String, session: ChampionshipSession)]
            switch arguments.sessionTypeScope {
            case .raceOnly:
                sessions = race.allSessions.filter { $0.name == "Race" }
            case .raceAndSprint:
                sessions = race.allSessions.filter { $0.name == "Race" || $0.name == "Sprint" }
            case .all:
                sessions = race.allSessions
            }
            for s in sessions {
                options.append(SessionOption(
                    raceName: race.raceName,
                    round: race.round,
                    sessionName: s.name,
                    formattedDateTime: s.session.formattedDateTime
                ))
            }
        }

        guard !options.isEmpty else { throw SelectSessionError.noSessionsFound }

        let selected = try await coordinator.requestSelection(options: options)
        return SelectSessionResult(selected: selected)
    }
}
