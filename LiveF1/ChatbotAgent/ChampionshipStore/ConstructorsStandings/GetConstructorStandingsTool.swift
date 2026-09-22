//
//  GetConstructorStandingsTool.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//

import Foundation
import FoundationModels

@Generable
struct GetConstructorStandingsArguments {
    @Guide(description: "Whether the user wants this — no filters needed, always returns full constructor standings")
    var placeholder: Bool
}

@Generable
struct ConstructorStandingEntry {
    var position: Int
    var constructorName: String
    var points: Double
    var wins: Int
}

@Generable
struct GetConstructorStandingsResult: Sendable {
    var standings: [ConstructorStandingEntry]
}

struct GetConstructorStandingsTool: Tool {
    let name = "getConstructorStandings"
    let description = "Returns current F1 constructor (team) championship standings — position, points, wins. Use this for questions about which team/constructor is leading."

    let store: ChampionshipDataStore
    let onResult: @Sendable (GetConstructorStandingsArguments, GetConstructorStandingsResult) -> Void

    func call(arguments: GetConstructorStandingsArguments) async throws -> GetConstructorStandingsResult {
        await store.fetchAllIfNeeded()
        
        let standings = await MainActor.run { store.constructorStandings }

        let entries = standings.map { s in
            ConstructorStandingEntry(
                position: Int(s.position) ?? 0,
                constructorName: s.constructor.name,
                points: Double(s.points) ?? 0,
                wins: Int(s.wins) ?? 0
            )
        }

        let result = GetConstructorStandingsResult(standings: entries)
        onResult(arguments, result)
        return result
    }
}
