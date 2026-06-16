//
//  StrategyCalculator.swift
//  LiveF1
//
//  Created by Riley Koo on 6/15/26.
//


// StrategyCalculator.swift

final class StrategyCalculator {
    static let shared = StrategyCalculator()
    private init() {}

    private let pitCost = 22.0

    // MARK: - Core Helpers

    func buildDegradationModels(from laps: [AnnotatedLap]) -> [TyreCompound: DegradationModel] {
        Dictionary(grouping: laps, by: \.compound)
            .compactMapValues { DegradationModelFactory.build(from: $0) }
    }

    func predictedTime(
        lap: Int,
        stint: F1PredictorStint,
        median: Double,
        trackModel: TrackEvolutionCalculator.TrackEvolutionModel,
        models: [TyreCompound: DegradationModel]
    ) -> Double {
        let compound = TyreCompound(rawValue: stint.compound) ?? .unknown
        let tyreAge = (lap - stint.lapStart) + stint.tyreAgeAtStart
        let trackDelta = trackModel.evolution(atLap: lap)
        guard let model = models[compound] else { return median }
        return median + (model.degradationRate * Double(tyreAge)) + trackDelta
    }

    func activeStint(for lap: Int, in stints: [F1PredictorStint]) -> F1PredictorStint? {
        stints.first { s in
            guard let end = s.lapEnd else { return false }
            return (s.lapStart...end).contains(lap)
        }
    }

    func totalRaceTime(
        for stints: [F1PredictorStint],
        median: Double,
        trackModel: TrackEvolutionCalculator.TrackEvolutionModel,
        models: [TyreCompound: DegradationModel]
    ) -> Double {
        stints.reduce(0.0) { total, stint in
            guard let range = stint.lapRange else { return total }
            let lapTimes = range.reduce(0.0) { $0 + predictedTime(lap: $1, stint: stint, median: median, trackModel: trackModel, models: models) }
            let pit = stint.stintNumber < stints.count ? pitCost : 0.0
            return total + lapTimes + pit
        }
    }

    // MARK: - Cumulative Delta Points

    func cumulativeDeltaPoints(
        actual: [F1PredictorStint],
        hypothetical: [F1PredictorStint],
        median: Double,
        trackModel: TrackEvolutionCalculator.TrackEvolutionModel,
        annotatedLaps: [AnnotatedLap]
    ) -> [DeltaPoint] {
        let totalLaps = max(
            actual.compactMap(\.lapEnd).max() ?? 0,
            hypothetical.compactMap(\.lapEnd).max() ?? 0
        )
        guard totalLaps > 0 else { return [] }

        let models = buildDegradationModels(from: annotatedLaps)
        let actualPitLaps = Set(actual.dropFirst().map(\.lapStart))
        let hypotheticalPitLaps = Set(hypothetical.dropFirst().map(\.lapStart))

        var cumulative = 0.0
        return (1...totalLaps).map { lap in
            let actualTime = activeStint(for: lap, in: actual)
                .map { predictedTime(lap: lap, stint: $0, median: median, trackModel: trackModel, models: models) }
                ?? median
            let hypoTime = activeStint(for: lap, in: hypothetical)
                .map { predictedTime(lap: lap, stint: $0, median: median, trackModel: trackModel, models: models) }
                ?? median

            var lapDelta = hypoTime - actualTime
            if hypotheticalPitLaps.contains(lap) { lapDelta += pitCost }
            if actualPitLaps.contains(lap) { lapDelta -= pitCost }

            cumulative += lapDelta
            return DeltaPoint(lap: lap, delta: cumulative)
        }
    }

    // MARK: - Time Delta vs Driver

    func timeDeltaVsDriver(
        hypothetical: [F1PredictorStint],
        baseStints: [F1PredictorStint],
        median: Double,
        trackModel: TrackEvolutionCalculator.TrackEvolutionModel,
        baseLaps: [AnnotatedLap]
    ) -> Double {
        let models = buildDegradationModels(from: baseLaps)
        return totalRaceTime(for: hypothetical, median: median, trackModel: trackModel, models: models)
             - totalRaceTime(for: baseStints,   median: median, trackModel: trackModel, models: models)
    }
}
