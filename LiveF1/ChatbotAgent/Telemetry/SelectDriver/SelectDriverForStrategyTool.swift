//
//  SelectDriverForStrategyTool.swift
//  Redline
//
//  Created by Riley Koo on 9/8/26.
//

import Foundation
import FoundationModels

@Generable
struct SelectDriverForStrategyArguments {
    @Guide(description: "Driver name as the user wrote it, exactly as typed — e.g. 'Max', 'Verstappen'. Don't correct spelling or guess a number yourself.")
    var driverNameQuery: String
}

@Generable
struct SelectDriverForStrategyResult: Sendable {
    var selectedDriver: Int
    var selectedDriverName: String
    var totalLaps: Int
    var actualStints: [String]
    var actualPitLaps: [Int]
    var actualCompounds: [String]
}

enum SelectDriverForStrategyError: LocalizedError {
    case noRaceLoaded
    case noDriversAvailable

    var errorDescription: String? {
        switch self {
        case .noRaceLoaded:
            return "No race is loaded yet. Call loadRaceForStrategy first."
        case .noDriversAvailable:
            return "No drivers are available for this session."
        }
    }
}

@MainActor
struct SelectDriverForStrategyTool: Tool {
    let name = "selectDriverForStrategy"
    let description = "Resolves the user's named driver to a driver number for the loaded race and returns their actual stint pattern. Call this after loadRaceForStrategy and before evaluateStrategy."

    let sessionStore: CurrentSessionStore
    let onResult: @Sendable (SelectDriverForStrategyResult) -> Void

    func call(arguments: SelectDriverForStrategyArguments) async throws -> SelectDriverForStrategyResult {
        print("\nDriver\n\(arguments)\n")
        guard let vm = sessionStore.raceViewModel else {
            throw SelectDriverForStrategyError.noRaceLoaded
        }

        let driverInfo = (try? await F1PredictorDriverParser.fetch(sessionKey: "\(vm.session.sessionKey)")) ?? []
        let candidates = driverInfo
            .filter { vm.drivers.contains($0.driverNumber) }
            .map { (number: $0.driverNumber, fullName: $0.fullName) }

        guard let matched = NameMatcher.bestGuess(for: arguments.driverNameQuery, in: candidates) else {
            throw SelectDriverForStrategyError.noDriversAvailable
        }

        vm.selectedDriverNumber = matched
        let matchedName = candidates.first(where: { $0.number == matched })?.fullName ?? "#\(matched)"

        let totalLaps = vm.laps
            .filter { $0.driverNumber == matched }
            .map { $0.lapNumber }
            .max() ?? 0

        let context = StrategyContextBuilder.build(
            session: vm.session, laps: vm.laps, stints: vm.stints, selectedDriver: matched
        )
        let actualStints = context.selectedDriverStints.map {
            "Laps \($0.lapStart)-\($0.lapEnd.map(String.init) ?? "?"): \($0.compound ?? "UNKNOWN")"
        }
        
        let templates = context.strategyTemplates.map { t in
            "\(t.stopCount) stop (\(t.compounds.joined(separator: " -> "))): pit around lap(s) \(t.averagePitLaps.map(String.init).joined(separator: ", ")) — used by \(t.driverCount) driver(s) this race"
        }

        let actualPitLaps = context.selectedDriverStints.dropLast().compactMap(\.lapEnd)
        let actualCompounds = context.selectedDriverStints.map { $0.compound ?? "UNKNOWN" }

        let result = SelectDriverForStrategyResult(
            selectedDriver: matched,
            selectedDriverName: matchedName,
            totalLaps: totalLaps,
            actualStints: actualStints,
            actualPitLaps: actualPitLaps,
            actualCompounds: actualCompounds
        )
        onResult(result)
        return result
    }
}

//
//import Foundation
//import FoundationModels
//
//@Generable
//struct SelectDriverForStrategyArguments {
//    @Guide(description: "Driver number for the driver the user is asking about. Must be a number from driverRoster returned by loadRaceForStrategy — do not use knowledge from training or any other tool to determine this number.")
//    var driverNumber: Int
//}
//
//@Generable
//struct SelectDriverForStrategyResult: Sendable {
//    var selectedDriver: Int
//    var totalLaps: Int
//    var actualStints: [String]
//}
//
//enum SelectDriverForStrategyError: LocalizedError {
//    case noRaceLoaded
//    case invalidDriver(requested: Int, valid: [Int])
//
//    var errorDescription: String? {
//        switch self {
//        case .noRaceLoaded:
//            return "No race is loaded yet. Call loadRaceForStrategy first."
//        case .invalidDriver(let requested, let valid):
//            return "Driver \(requested) didn't race in this session. Valid driver numbers: \(valid.map(String.init).joined(separator: ", "))."
//        }
//    }
//}
//
//@MainActor
//struct SelectDriverForStrategyTool: Tool {
//    let name = "selectDriverForStrategy"
//    let description = "Selects which driver to analyze in the currently loaded race, and returns their total laps and actual stint pattern. Call this after loadRaceForStrategy and before evaluateStrategy."
//
//    let sessionStore: CurrentSessionStore
//
//    func call(arguments: SelectDriverForStrategyArguments) async throws -> SelectDriverForStrategyResult {
//        print("\nDriver\n\(arguments)\n")
//        guard let vm = sessionStore.raceViewModel else {
//            throw SelectDriverForStrategyError.noRaceLoaded
//        }
//        guard vm.drivers.contains(arguments.driverNumber) else {
//            throw SelectDriverForStrategyError.invalidDriver(requested: arguments.driverNumber, valid: vm.drivers)
//        }
//        print("\nAvail\n\(vm.drivers)\n")
//        guard vm.drivers.contains(arguments.driverNumber) else {
//            throw SelectDriverForStrategyError.invalidDriver(requested: arguments.driverNumber, valid: vm.drivers)
//        }
//
//        vm.selectedDriverNumber = arguments.driverNumber
//
//        let totalLaps = vm.laps
//            .filter { $0.driverNumber == arguments.driverNumber }
//            .map { $0.lapNumber }
//            .max() ?? 0
//
//        let context = StrategyContextBuilder.build(
//            session: vm.session, laps: vm.laps, stints: vm.stints, selectedDriver: arguments.driverNumber
//        )
//        let actualStints = context.selectedDriverStints.map {
//            "Laps \($0.lapStart)-\($0.lapEnd): \($0.compound)"
//        }
//
//        return SelectDriverForStrategyResult(
//            selectedDriver: arguments.driverNumber,
//            totalLaps: totalLaps,
//            actualStints: actualStints
//        )
//    }
//}
