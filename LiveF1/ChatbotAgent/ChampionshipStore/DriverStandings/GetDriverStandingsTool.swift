//
//  GetDriverStandingsTool.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//

import Foundation
import FoundationModels

@Generable
struct GetDriverStandingsArguments {
    @Guide(description: "Optional constructor name to filter standings to, e.g. 'Red Bull' or 'Ferrari'. Omit to get all drivers.")
    var constructorFilter: String?
}

@Generable
struct DriverStandingEntry {
    var position: Int
    var driverName: String
    var constructorName: String
    var points: Double
    var wins: Int
    var number: Int
}

@Generable
struct GetDriverStandingsResult: Sendable {
    var standings: [DriverStandingEntry]
}

struct GetDriverStandingsTool: Tool {
    let name = "getDriverStandings"
    let description = "Returns current F1 driver championship standings (position, points, wins), optionally filtered to one constructor. Use this for any question about who is leading, points gaps, or driver rankings."

    let store: ChampionshipDataStore
    let onResult: @Sendable (GetDriverStandingsArguments, GetDriverStandingsResult) -> Void

    func call(arguments: GetDriverStandingsArguments) async throws -> GetDriverStandingsResult {
        await store.fetchAllIfNeeded()
        
        let standings = await MainActor.run { store.driverStandings }

        let filtered = standings.filter { s in
            guard let filter = arguments.constructorFilter else { return true }
            return s.constructors.contains {
                $0.name.localizedCaseInsensitiveContains(filter)
            }
        }

        let entries = filtered.map { s in
            DriverStandingEntry(
                position: Int(s.position) ?? 0,
                driverName: s.driver.fullName,
                constructorName: s.constructors.first?.name ?? "Unknown",
                points: Double(s.points) ?? 0,
                wins: Int(s.wins) ?? 0,
                number: Int(s.driver.permanentNumber ?? "0") ?? 0
            )
        }

        let result = GetDriverStandingsResult(standings: entries)
        onResult(arguments, result)
        return result
    }
}
