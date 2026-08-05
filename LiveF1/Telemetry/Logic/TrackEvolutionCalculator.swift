//
//  TrackEvolutionCalculator.swift
//  LiveF1
//
//  Created by Riley Koo on 6/15/26.
//


//  TrackEvolutionCalculator.swift

import Foundation

struct TrackEvolutionCalculator {

    // MARK: - Track Evolution Model

    struct TrackEvolutionModel {
        let regressionSlope: Double
        let regressionIntercept: Double
        let medianDeltaPerLap: [Int: Double] // lap number -> median delta

        func evolution(atLap lap: Int) -> Double {
            regressionIntercept + regressionSlope * Double(lap)
        }
    }

    // MARK: - Build

    static func build(from laps: [F1Lap]) -> TrackEvolutionModel? {
        // Step 1 — filter to clean laps only
        let cleanLaps = laps.filter {
            !$0.isPitOutLap && $0.lapDuration != nil
        }
        guard !cleanLaps.isEmpty else { return nil }

        // Step 2 — per driver, calculate their median clean lap time
        let byDriver = Dictionary(grouping: cleanLaps, by: \.driverNumber)
        var driverMedians: [Int: Double] = [:]
        for (driver, driverLaps) in byDriver {
            let sorted = driverLaps.compactMap { $0.lapDuration }.sorted()
            guard !sorted.isEmpty else { continue }
            driverMedians[driver] = sorted[sorted.count / 2]
        }

        // Step 3 — express each lap as delta from driver's own median
        // also filter out laps more than 7% above median (SC, VSC, outliers)
        var deltasByLap: [Int: [Double]] = [:]
        for lap in cleanLaps {
            guard let duration = lap.lapDuration,
                  let median = driverMedians[lap.driverNumber],
                  duration <= median * 1.07
            else { continue }
            let delta = duration - median
            deltasByLap[lap.lapNumber, default: []].append(delta)
        }

        // Step 4 — per lap number, take median delta across all drivers
        var medianDeltaPerLap: [Int: Double] = [:]
        for (lapNumber, deltas) in deltasByLap {
            guard deltas.count >= 3 else { continue } // need enough drivers for meaningful median
            let sorted = deltas.sorted()
            medianDeltaPerLap[lapNumber] = sorted[sorted.count / 2]
        }
        guard medianDeltaPerLap.count >= 5 else { return nil }

        // Step 5 — fit linear regression through median deltas to smooth
        let points = medianDeltaPerLap.map { (x: Double($0.key), y: $0.value) }
        let n = Double(points.count)
        let sumX = points.map { $0.x }.reduce(0, +)
        let sumY = points.map { $0.y }.reduce(0, +)
        let sumXY = points.map { $0.x * $0.y }.reduce(0, +)
        let sumX2 = points.map { $0.x * $0.x }.reduce(0, +)
        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return nil }
        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n

        return TrackEvolutionModel(
            regressionSlope: slope,
            regressionIntercept: intercept,
            medianDeltaPerLap: medianDeltaPerLap
        )
    }

    // MARK: - Adjusted degradation

    /// Subtract track evolution from a lap's duration to get true tyre delta
    static func adjustedDuration(
        lap: F1Lap,
        driverMedian: Double,
        trackModel: TrackEvolutionModel
    ) -> Double? {
        guard let duration = lap.lapDuration else { return nil }
        let delta = duration - driverMedian
        let trackDelta = trackModel.evolution(atLap: lap.lapNumber)
        return delta - trackDelta // positive = slower than track evo adjusted pace
    }
}