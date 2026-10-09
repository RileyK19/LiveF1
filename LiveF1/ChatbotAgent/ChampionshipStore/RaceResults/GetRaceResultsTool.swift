//
//  GetRaceResultsTool.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//

import Foundation
import FoundationModels

@Generable
struct GetRaceResultsArguments {
    @Guide(description: "The race name or circuit/location the user is asking about, e.g. 'Zandvoort', 'Dutch Grand Prix', 'Monaco'. Do not guess a round number — pass the name as given. Or provide 'last' or 'next' instead of the name.")
    var raceQuery: String
}

@Generable
struct RaceResultEntry {
    var position: Int
    var driverName: String
    var constructorName: String
    var points: Double
    var status: String
}

@Generable
struct GetRaceResultsResult: Sendable {
    var results: [RaceResultEntry]
}

struct GetRaceResultsTool: Tool {
    let name = "getRaceResults"
    let description = "Returns the finishing results for a specific completed race round, including position, points, and finishing status for each driver. Requires a round number."

    let store: ChampionshipDataStore
    let onResult: @Sendable (GetRaceResultsArguments, GetRaceResultsResult) -> Void

    enum GetRaceResultsToolError: Error {
        case raceNotFound
    }

    func call(arguments: GetRaceResultsArguments) async throws -> GetRaceResultsResult {
        await store.fetchAllIfNeeded()
        
        var race: ChampionshipRace? = await MainActor.run {
            let query = arguments.raceQuery
                .lowercased()
                .replacingOccurrences(of: "gp", with: "")
                .replacingOccurrences(of: "grand prix", with: "")
                .replacingOccurrences(of: " ", with: "")
            return store.races.first {
                $0.raceName.lowercased().contains(query) ||
                $0.circuit.circuitName.lowercased().contains(query) ||
                $0.circuit.location.locality.lowercased().contains(query) ||
                $0.circuit.location.country.lowercased().contains(query)
            }
        }
        
        if arguments.raceQuery == "next" {
            race = await store.races.sorted(by: { r1, r2 in
                r1.date < r2.date
            }).first {
                $0.isNext
            }
        } else if arguments.raceQuery == "last" {
            race = await store.races.sorted(by: { r1, r2 in
                r1.date > r2.date
            }).first {
                $0.isPast
            }
        }

        guard let race else { throw GetRaceResultsToolError.raceNotFound }

        await store.fetchRaceResults(round: race.round)
        let results = await MainActor.run { store.raceResults }

        let entries = results.map { r in
            RaceResultEntry(
                position: Int(r.position) ?? 0,
                driverName: r.driverName,
                constructorName: r.constructorName,
                points: Double(r.points) ?? 0,
                status: r.status
            )
        }

        let result = GetRaceResultsResult(results: entries)
        onResult(arguments, result)
        return result
    }
}
