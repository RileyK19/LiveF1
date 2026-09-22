//
//  EvaluateStrategyTool.swift
//  LiveF1
//
//  Created by Riley Koo on 7/15/26.
//

import Foundation
import FoundationModels
import Combine

@Generable
struct EvaluateStrategyArguments {
    @Guide(description: "Hypothetical strategy to evaluate")
    var hypotheticalStints: [GeneratedStint]
    @Guide(description: "Briefly state, in one sentence, how these stints differ from the driver's actualStints and why — e.g. 'Same as actual but pit 5 laps earlier on lap 23 instead of 28' or 'Fresh 1-stop strategy instead of the actual 2-stop'. This must reflect what was actually changed below.")
    var changeSummary: String
}

@Generable
struct EvaluateStrategyResult: Sendable {
    var success: Bool
    var errorMessage: String?
    var totalRaceTimeSeconds: Double?
    var deltaVsActualSeconds: Double?
    var stopCountEvaluated: Int?
    var compoundsUsed: [String]?
    var identicalToActualStrategy: Bool
    var structuralDiff: [String]
}

enum EvaluateStrategyError: LocalizedError {
    case noRaceLoaded, noDriverSelected, insufficientData
    case invalidCompound(String)
    case invalidStintSequence(String)

    var errorDescription: String? {
        switch self {
        case .noRaceLoaded: return "No race is loaded yet. Call loadRaceForStrategy first."
        case .noDriverSelected: return "No driver is selected. Call selectDriverForStrategy first."
        case .insufficientData: return "Not enough lap data to evaluate this strategy yet."
        case .invalidCompound(let c): return "'\(c)' isn't a valid compound. Use SOFT, MEDIUM, HARD, INTERMEDIATE, or WET."
        case .invalidStintSequence(let reason): return reason
        }
    }
}

@MainActor
struct EvaluateStrategyTool: Tool {
    let name = "evaluateStrategy"
    let description = "Runs a candidate stint sequence through the tyre degradation model and returns its total race time, delta vs. the driver's actual race, and a structural diff showing exactly what changed. Requires a race and driver to already be selected. Always call this before stating a time delta."

    let sessionStore: CurrentSessionStore
    let onResult: @Sendable ([F1PredictorStint], EvaluateStrategyResult) -> Void
    
    func call(arguments: EvaluateStrategyArguments) async throws -> EvaluateStrategyResult {
        print(arguments)
        guard let vm = sessionStore.raceViewModel else {
            throw EvaluateStrategyError.noRaceLoaded
        }
        guard let driver = vm.selectedDriverNumber else {
            throw EvaluateStrategyError.noDriverSelected
        }
        guard let median = vm.driverMedianLapTime,
              let trackModel = vm.trackEvolutionModel,
              !vm.annotatedLaps.isEmpty
        else {
            print("GUARD FAILED — median: \(vm.driverMedianLapTime != nil), trackModel: \(vm.trackEvolutionModel != nil), laps: \(vm.annotatedLaps.count)")
            throw EvaluateStrategyError.insufficientData
        }

        let context = StrategyContextBuilder.build(
            session: vm.session, laps: vm.laps, stints: vm.stints, selectedDriver: driver
        )

        let totalLaps = vm.laps.filter { $0.driverNumber == driver }.map { $0.lapNumber }.max() ?? 0

        var hypoStints: [F1PredictorStint] = []
        for (i, s) in arguments.hypotheticalStints.enumerated() {
            hypoStints.append(F1PredictorStint(
                meetingKey: 0, sessionKey: 0, stintNumber: i + 1,
                driverNumber: driver, lapStart: s.lapStart, lapEnd: s.lapEnd,
                compound: s.compound, tyreAgeAtStart: 0
            ))
        }

        if let first = hypoStints.first, first.lapStart != 1 {
            hypoStints[0] = F1PredictorStint(
                meetingKey: first.meetingKey, sessionKey: first.sessionKey, stintNumber: first.stintNumber,
                driverNumber: first.driverNumber, lapStart: 1, lapEnd: first.lapEnd,
                compound: first.compound, tyreAgeAtStart: first.tyreAgeAtStart
            )
        }

        if let last = hypoStints.last, last.lapEnd != totalLaps {
            let lastIndex = hypoStints.count - 1
            hypoStints[lastIndex] = F1PredictorStint(
                meetingKey: last.meetingKey, sessionKey: last.sessionKey, stintNumber: last.stintNumber,
                driverNumber: last.driverNumber, lapStart: last.lapStart, lapEnd: totalLaps,
                compound: last.compound, tyreAgeAtStart: last.tyreAgeAtStart
            )
        }

        if hypoStints.count > 1 {
            for i in 1..<hypoStints.count {
                let expectedStart = (hypoStints[i-1].lapEnd ?? 0) + 1
                if hypoStints[i].lapStart != expectedStart {
                    let s = hypoStints[i]
                    hypoStints[i] = F1PredictorStint(
                        meetingKey: s.meetingKey, sessionKey: s.sessionKey, stintNumber: s.stintNumber,
                        driverNumber: s.driverNumber, lapStart: expectedStart, lapEnd: s.lapEnd,
                        compound: s.compound, tyreAgeAtStart: s.tyreAgeAtStart
                    )
                }
            }
        }

        print(hypoStints)

        // Generic structural diff — works for any kind of edit, not just stop count.
        var diff: [String] = []
        if hypoStints.count != context.selectedDriverStints.count {
            diff.append("stint count: \(context.selectedDriverStints.count) → \(hypoStints.count)")
        }
        for i in 0..<min(hypoStints.count, context.selectedDriverStints.count) {
            let h = hypoStints[i], a = context.selectedDriverStints[i]
            if h.lapEnd != a.lapEnd {
                diff.append("stint \(i+1) end lap: \(a.lapEnd.map(String.init) ?? "?") → \(h.lapEnd.map(String.init) ?? "?")")
            }
            if h.compound != a.compound {
                diff.append("stint \(i+1) compound: \(a.compound ?? "?") → \(h.compound ?? "?")")
            }
        }

        let calc = StrategyCalculator.shared
        let models = calc.buildDegradationModels(from: vm.annotatedLaps)
        let hypoTime = calc.totalRaceTime(for: hypoStints, median: median, trackModel: trackModel, models: models)
        let actualTime = calc.totalRaceTime(for: context.selectedDriverStints, median: median, trackModel: trackModel, models: models)

        let stopCount = hypoStints.count - 1
        let identical = diff.isEmpty

        if identical {
            return EvaluateStrategyResult(
                success: false,
                errorMessage: "This hypothetical is identical to the driver's actual strategy (\(hypoStints.count) stints: \(hypoStints.map { $0.compound ?? "?" }.joined(separator: ", "))). If the user asked for any change, you have not applied it. Re-read their request and build a genuinely different hypotheticalStints sequence, then call evaluateStrategy again.",
                totalRaceTimeSeconds: nil,
                deltaVsActualSeconds: nil,
                stopCountEvaluated: nil,
                compoundsUsed: nil,
                identicalToActualStrategy: true,
                structuralDiff: []
            )
        }

        let result = EvaluateStrategyResult(
            success: true,
            errorMessage: nil,
            totalRaceTimeSeconds: hypoTime,
            deltaVsActualSeconds: hypoTime - actualTime,
            stopCountEvaluated: stopCount,
            compoundsUsed: hypoStints.map { $0.compound ?? "UNKNOWN" },
            identicalToActualStrategy: false,
            structuralDiff: diff
        )
        print("RESULT\(result)")
        onResult(hypoStints, result)
        return result
    }
}

//
//import Foundation
//import FoundationModels
//import Combine
//
//@Generable
//struct EvaluateStrategyArguments {
//    @Guide(description: "Hypothetical strategy to evaluate")
//    var hypotheticalStints: [GeneratedStint]
////    @Guide(description: "Number of pit stops this strategy represents, if the user specified a stop count (e.g. 'one stop' = 1). Omit if the user didn't specify a stop count.")
////    var requestedStopCount: Int?
//    @Guide(description: "Briefly state, in one sentence, how these stints differ from the driver's actualStints and why — e.g. 'Same as actual but pit 5 laps earlier on lap 23 instead of 28' or 'Fresh 1-stop strategy instead of the actual 2-stop'. This must reflect what was actually changed below.")
//    var changeSummary: String
//}
//
//@Generable
//struct EvaluateStrategyResult: Sendable {
//    var success: Bool
//    var errorMessage: String?
//    var totalRaceTimeSeconds: Double?
//    var deltaVsActualSeconds: Double?
//    var stopCountEvaluated: Int?
//    var compoundsUsed: [String]?
//    var identicalToActualStrategy: Bool
//    var structuralDiff: [String] 
//}
//
//enum EvaluateStrategyError: LocalizedError {
//    case noRaceLoaded, noDriverSelected, insufficientData
//    case invalidCompound(String)
//    case invalidStintSequence(String)
//
//    var errorDescription: String? {
//        switch self {
//        case .noRaceLoaded: return "No race is loaded yet. Call loadRaceForStrategy first."
//        case .noDriverSelected: return "No driver is selected. Call loadRaceForStrategy with a driverNumber."
//        case .insufficientData: return "Not enough lap data to evaluate this strategy yet."
//        case .invalidCompound(let c): return "'\(c)' isn't a valid compound. Use SOFT, MEDIUM, HARD, INTERMEDIATE, or WET."
//        case .invalidStintSequence(let reason): return reason
//        }
//    }
//}
//
//@MainActor
//struct EvaluateStrategyTool: Tool {
//    let name = "evaluateStrategy"
//    let description = "Runs a candidate stint sequence through the tyre degradation model and returns its total race time and delta vs. the driver's actual race. Requires a race to already be loaded via loadRaceForStrategy. Always call this before stating a time delta."
//
//    let sessionStore: CurrentSessionStore
//    let onResult: @Sendable (EvaluateStrategyArguments, EvaluateStrategyResult) -> Void
//
//    func call(arguments: EvaluateStrategyArguments) async throws -> EvaluateStrategyResult {
//        print(arguments)
//        guard let vm = sessionStore.raceViewModel else {
//            throw EvaluateStrategyError.noRaceLoaded
//        }
//        guard let driver = vm.selectedDriverNumber else {
//            throw EvaluateStrategyError.noDriverSelected
//        }
//        guard let median = vm.driverMedianLapTime,
//              let trackModel = vm.trackEvolutionModel,
//              !vm.annotatedLaps.isEmpty
//        else {
//            if vm.driverMedianLapTime == nil { print ("no medians") }
//            if vm.trackEvolutionModel == nil { print ("no evo model") }
//            if vm.annotatedLaps.isEmpty { print ("empty laps") }
//            throw EvaluateStrategyError.insufficientData
//        }
//
//        let context = StrategyContextBuilder.build(
//            session: vm.session, laps: vm.laps, stints: vm.stints, selectedDriver: driver
//        )
//
//        let totalLaps = vm.laps.filter { $0.driverNumber == driver }.map { $0.lapNumber }.max() ?? 0
//
//        var hypoStints: [F1PredictorStint] = []
//        for (i, s) in arguments.hypotheticalStints.enumerated() {
//            hypoStints.append(F1PredictorStint(
//                meetingKey: 0, sessionKey: 0, stintNumber: i + 1,
//                driverNumber: driver, lapStart: s.lapStart, lapEnd: s.lapEnd,
//                compound: s.compound, tyreAgeAtStart: 0
//            ))
//        }
//
//        // Auto-clamp first stint to start at lap 1
//        if let first = hypoStints.first, first.lapStart != 1 {
//            hypoStints[0] = F1PredictorStint(
//                meetingKey: first.meetingKey, sessionKey: first.sessionKey, stintNumber: first.stintNumber,
//                driverNumber: first.driverNumber, lapStart: 1, lapEnd: first.lapEnd,
//                compound: first.compound, tyreAgeAtStart: first.tyreAgeAtStart
//            )
//        }
//
//        // Auto-clamp last stint to end at the final lap
//        if let last = hypoStints.last, last.lapEnd != totalLaps {
//            let lastIndex = hypoStints.count - 1
//            hypoStints[lastIndex] = F1PredictorStint(
//                meetingKey: last.meetingKey, sessionKey: last.sessionKey, stintNumber: last.stintNumber,
//                driverNumber: last.driverNumber, lapStart: last.lapStart, lapEnd: totalLaps,
//                compound: last.compound, tyreAgeAtStart: last.tyreAgeAtStart
//            )
//        }
//
//        // Auto-close any gaps/overlaps between consecutive stints
//        if hypoStints.count > 1 {
//            for i in 1..<hypoStints.count {
//                let expectedStart = (hypoStints[i-1].lapEnd ?? 0) + 1
//                if hypoStints[i].lapStart != expectedStart {
//                    let s = hypoStints[i]
//                    hypoStints[i] = F1PredictorStint(
//                        meetingKey: s.meetingKey, sessionKey: s.sessionKey, stintNumber: s.stintNumber,
//                        driverNumber: s.driverNumber, lapStart: expectedStart, lapEnd: s.lapEnd,
//                        compound: s.compound, tyreAgeAtStart: s.tyreAgeAtStart
//                    )
//                }
//            }
//        }
//
////        // This one stays a hard failure — wrong stint COUNT is a semantic error, not boundary noise
////        if let requested = arguments.requestedStopCount {
////            let actualStops = hypoStints.count - 1
////            if actualStops != requested {
////                return EvaluateStrategyResult(success: false, errorMessage: "You said \(requested) stop(s), but this sequence has \(hypoStints.count) stints (\(actualStops) stops). A \(requested)-stop strategy needs exactly \(requested + 1) stints. Fix and call evaluateStrategy again.", totalRaceTimeSeconds: nil, deltaVsActualSeconds: nil)
////            }
////        }
//print(hypoStints)
//        let calc = StrategyCalculator.shared
//        let models = calc.buildDegradationModels(from: vm.annotatedLaps)
//        let hypoTime = calc.totalRaceTime(for: hypoStints, median: median, trackModel: trackModel, models: models)
//        let actualTime = calc.totalRaceTime(for: context.selectedDriverStints, median: median, trackModel: trackModel, models: models)
//
//        let stopCount = hypoStints.count - 1
//        let identical = hypoStints.count == context.selectedDriverStints.count &&
//            zip(hypoStints, context.selectedDriverStints).allSatisfy { hypo, actual in
//                hypo.lapStart == actual.lapStart &&
//                hypo.lapEnd == actual.lapEnd &&
//                hypo.compound == actual.compound
//            }
//
//        if identical {
//            return EvaluateStrategyResult(
//                success: false,
//                errorMessage: "This hypothetical is identical to the driver's actual strategy (\(hypoStints.count) stints: \(hypoStints.map { $0.compound ?? "?" }.joined(separator: ", "))). If the user asked for any change, you have not applied it. Re-read their request and build a genuinely different hypotheticalStints sequence, then call evaluateStrategy again.",
//                totalRaceTimeSeconds: nil,
//                deltaVsActualSeconds: nil,
//                stopCountEvaluated: nil,
//                compoundsUsed: nil,
//                identicalToActualStrategy: true,
//                structuralDiff: []
//            )
//        }
//        
//        var diff: [String] = []
//        if hypoStints.count != context.selectedDriverStints.count {
//            diff.append("stint count: \(context.selectedDriverStints.count) → \(hypoStints.count)")
//        }
//        for i in 0..<min(hypoStints.count, context.selectedDriverStints.count) {
//            let h = hypoStints[i], a = context.selectedDriverStints[i]
//            if h.lapEnd != a.lapEnd {
//                diff.append("stint \(i+1) end lap: \(a.lapEnd.map(String.init) ?? "?") → \(h.lapEnd.map(String.init) ?? "?")")
//            }
//            if h.compound != a.compound {
//                diff.append("stint \(i+1) compound: \(a.compound ?? "?") → \(h.compound ?? "?")")
//            }
//        }
//
//        let result = EvaluateStrategyResult(
//            success: true,
//            errorMessage: nil,
//            totalRaceTimeSeconds: hypoTime,
//            deltaVsActualSeconds: hypoTime - actualTime,
//            stopCountEvaluated: stopCount,
//            compoundsUsed: hypoStints.map { $0.compound ?? "UNKNOWN" },
//            identicalToActualStrategy: identical,
//            structuralDiff: diff
//        )
//        print("RESULT\(result)")
//        onResult(arguments, result)
//        return result
//    }
//}
