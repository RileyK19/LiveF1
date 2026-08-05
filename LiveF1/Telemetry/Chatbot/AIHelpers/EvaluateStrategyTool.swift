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
    @Guide(description: "Candidate stint sequence to evaluate")
    var stints: [GeneratedStint]
}

@Generable
struct EvaluateStrategyResult: Sendable {
    var totalRaceTimeSeconds: Double
    var deltaVsActualSeconds: Double
}

struct EvaluateStrategyTool: Tool {
    let name = "evaluateStrategy"
    let description = "Runs a candidate stint sequence through the tyre degradation model and returns its total race time and delta vs. the driver's actual race. Always call this before stating a time delta, and call it once per candidate when comparing multiple strategies."

    let context: StrategyContext
    let median: Double
    let trackModel: TrackEvolutionCalculator.TrackEvolutionModel
    let annotatedLaps: [AnnotatedLap]
    let onResult: @Sendable (EvaluateStrategyArguments, EvaluateStrategyResult) -> Void

    func call(arguments: EvaluateStrategyArguments) async throws -> EvaluateStrategyResult {
        let hypoStints = arguments.stints.enumerated().map { i, s in
            F1PredictorStint(
                meetingKey: 0, sessionKey: 0, stintNumber: i + 1,
                driverNumber: context.selectedDriver,
                lapStart: s.lapStart, lapEnd: s.lapEnd,
                compound: s.compound, tyreAgeAtStart: 0
            )
        }

        let calc = StrategyCalculator.shared
        let models = calc.buildDegradationModels(from: annotatedLaps)

        let hypoTime = calc.totalRaceTime(
            for: hypoStints, median: median, trackModel: trackModel, models: models
        )
        let actualTime = calc.totalRaceTime(
            for: context.selectedDriverStints, median: median, trackModel: trackModel, models: models
        )

        let result = EvaluateStrategyResult(
            totalRaceTimeSeconds: hypoTime,
            deltaVsActualSeconds: hypoTime - actualTime
        )
        onResult(arguments, result)
        return result
    }
}
