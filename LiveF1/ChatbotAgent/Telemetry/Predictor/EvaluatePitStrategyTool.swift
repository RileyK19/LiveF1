//
//  EvaluatePitStrategyTool.swift
//  Redline
//
//  Created by Riley Koo on 9/10/26.
//

import Foundation
import FoundationModels
import Combine

@Generable
struct EvaluatePitStrategyArguments {
    @Guide(description: "Pit laps in ascending order. MUST have exactly compounds.count - 1 entries. To move stop N by X laps: take actualPitLaps, keep every entry except index N-1, and set that one entry to actualPitLaps[N-1] + X. Do not add, remove, or reorder entries beyond that.")
    var pitLaps: [Int]
    
    @Guide(description: "One compound per stint, in order. Length MUST equal pitLaps.count + 1. For a delta request, copy actualCompounds unchanged unless the user asked to change a compound.")
    var compounds: [String]
    
    @Guide(description: "State the exact arithmetic you did, e.g. 'actualPitLaps[1] = 28, requested +5, new value = 33'.")
    var changeSummary: String
    
    @Guide(description: "Copy this verbatim from selectDriverForStrategy's actualPitLaps, then apply your requested edit.")
    var actualPitLaps: [Int]
}

@Generable
struct EvaluatePitStrategyResult: Sendable {
    var success: Bool
    var errorMessage: String?
    var totalRaceTimeSeconds: Double?
    var deltaVsActualSeconds: Double?
    var stopCountEvaluated: Int?
    var compoundsUsed: [String]?
    var identicalToActualStrategy: Bool
    var structuralDiff: [String]
}

enum EvaluatePitStrategyError: LocalizedError {
    case noRaceLoaded, noDriverSelected, insufficientData

    var errorDescription: String? {
        switch self {
        case .noRaceLoaded: return "No race is loaded yet. Call loadRaceForStrategy first."
        case .noDriverSelected: return "No driver is selected. Call selectDriverForStrategy first."
        case .insufficientData: return "Not enough lap data to evaluate this strategy yet."
        }
    }
}

@MainActor
struct EvaluatePitStrategyTool: Tool {
    let name = "evaluatePitStrategy"
    let description = "Runs a candidate pit-stop plan (pit laps + compounds) through the tyre degradation model and returns its total race time, delta vs. the driver's actual race, and a structural diff. Requires a race and driver to already be selected. Always call this before stating a time delta."

    let sessionStore: CurrentSessionStore
    let onResult: @Sendable ([F1PredictorStint], EvaluatePitStrategyResult) -> Void

    func call(arguments: EvaluatePitStrategyArguments) async throws -> EvaluatePitStrategyResult {
        print(arguments)
        guard let vm = sessionStore.raceViewModel else {
            throw EvaluatePitStrategyError.noRaceLoaded
        }
        guard let driver = vm.selectedDriverNumber else {
            throw EvaluatePitStrategyError.noDriverSelected
        }
        guard let median = vm.driverMedianLapTime,
              let trackModel = vm.trackEvolutionModel,
              !vm.annotatedLaps.isEmpty
        else {
            print("GUARD FAILED — median: \(vm.driverMedianLapTime != nil), trackModel: \(vm.trackEvolutionModel != nil), laps: \(vm.annotatedLaps.count)")
            throw EvaluatePitStrategyError.insufficientData
        }

        let totalLaps = vm.laps.filter { $0.driverNumber == driver }.map { $0.lapNumber }.max() ?? 0

        // Structural validation — cheap, exact, catches malformed input before any construction.
        guard arguments.compounds.count == arguments.pitLaps.count + 1 else {
            return EvaluatePitStrategyResult(
                success: false,
                errorMessage: "compounds must have exactly \(arguments.pitLaps.count + 1) entries (pitLaps.count + 1), you gave \(arguments.compounds.count). Fix and call evaluatePitStrategy again.",
                totalRaceTimeSeconds: nil, deltaVsActualSeconds: nil,
                stopCountEvaluated: nil, compoundsUsed: nil,
                identicalToActualStrategy: false, structuralDiff: []
            )
        }
        let sortedPits = arguments.pitLaps.sorted()
        guard sortedPits == arguments.pitLaps, sortedPits.allSatisfy({ $0 > 0 && $0 < totalLaps }) else {
            return EvaluatePitStrategyResult(
                success: false,
                errorMessage: "pitLaps must be strictly ascending and each between 1 and \(totalLaps - 1). Got \(arguments.pitLaps). Fix and call evaluatePitStrategy again.",
                totalRaceTimeSeconds: nil, deltaVsActualSeconds: nil,
                stopCountEvaluated: nil, compoundsUsed: nil,
                identicalToActualStrategy: false, structuralDiff: []
            )
        }

        // Deterministic construction — Swift computes every boundary, model never touches per-stint lap numbers.
        let boundaries = [1] + sortedPits.map { $0 + 1 }
        let ends = sortedPits + [totalLaps]
        let hypoStints = zip(boundaries, ends).enumerated().map { i, pair in
            F1PredictorStint(
                meetingKey: 0, sessionKey: 0, stintNumber: i + 1, driverNumber: driver,
                lapStart: pair.0, lapEnd: pair.1, compound: arguments.compounds[i], tyreAgeAtStart: 0
            )
        }
        print(hypoStints)

        let context = StrategyContextBuilder.build(
            session: vm.session, laps: vm.laps, stints: vm.stints, selectedDriver: driver
        )

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

        if diff.isEmpty {
            return EvaluatePitStrategyResult(
                success: false,
                errorMessage: "This is identical to the driver's actual strategy (pit laps \(sortedPits), compounds \(arguments.compounds)). If the user asked for any change, you have not applied it. Adjust pitLaps/compounds and call evaluatePitStrategy again.",
                totalRaceTimeSeconds: nil, deltaVsActualSeconds: nil,
                stopCountEvaluated: nil, compoundsUsed: nil,
                identicalToActualStrategy: true, structuralDiff: []
            )
        }

        let result = EvaluatePitStrategyResult(
            success: true,
            errorMessage: nil,
            totalRaceTimeSeconds: hypoTime,
            deltaVsActualSeconds: hypoTime - actualTime,
            stopCountEvaluated: sortedPits.count,
            compoundsUsed: arguments.compounds,
            identicalToActualStrategy: false,
            structuralDiff: diff
        )
        print("RESULT\(result)")
        onResult(hypoStints, result)
        return result
    }
}
