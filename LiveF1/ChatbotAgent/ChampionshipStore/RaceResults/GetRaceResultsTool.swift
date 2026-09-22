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
    @Guide(description: "The race name or circuit/location the user is asking about, e.g. 'Zandvoort', 'Dutch Grand Prix', 'Monaco'. Do not guess a round number — pass the name as given.")
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
        
        let race: ChampionshipRace? = await MainActor.run {
            let query = arguments.raceQuery.lowercased()
            return store.races.first {
                $0.raceName.lowercased().contains(query) ||
                $0.circuit.circuitName.lowercased().contains(query) ||
                $0.circuit.location.locality.lowercased().contains(query) ||
                $0.circuit.location.country.lowercased().contains(query)
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
