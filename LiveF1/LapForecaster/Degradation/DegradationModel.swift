//
//  DegradationModel.swift
//  LiveF1
//
//  Created by Riley Koo on 6/15/26.
//


//  DegradationModel.swift

import Foundation

// MARK: - Protocol

protocol DegradationModel {
    func predictedLapTime(atTyreAge age: Int) -> Double
    var degradationRate: Double { get }
    var baseLapTime: Double { get }
    var modelType: DegradationModelType { get }
}

enum DegradationModelType {
    case linear
    // case polynomial(degree: Int)
    // case exponential
}

// MARK: - Linear

struct LinearDegradationModel: DegradationModel {
    let baseLapTime: Double
    let degradationRate: Double
    let modelType: DegradationModelType = .linear

    func predictedLapTime(atTyreAge age: Int) -> Double {
        baseLapTime + (degradationRate * Double(age))
    }
}

// MARK: - Factory

struct DegradationModelFactory {

    // MARK: - Outlier filtering

    /// Hard filter — remove pit out laps and laps over 107% of median
    static func hardFilter(_ laps: [AnnotatedLap]) -> [AnnotatedLap] {
        let clean = laps.filter { !$0.lap.isPitOutLap && $0.tyreAge > 2 }
        guard !clean.isEmpty else { return [] }
        let sorted = clean.map { $0.lapDuration }.sorted()
        let median = sorted[sorted.count / 2]
        return clean.filter { $0.lapDuration <= median * 1.07 }
    }

    /// Soft filter — after initial fit, drop laps > 2 std deviations from predicted
    static func softFilter(_ laps: [AnnotatedLap], model: DegradationModel) -> [AnnotatedLap] {
        let residuals = laps.map { $0.lapDuration - model.predictedLapTime(atTyreAge: $0.tyreAge) }
        let mean = residuals.reduce(0, +) / Double(residuals.count)
        let variance = residuals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(residuals.count)
        let stdDev = sqrt(variance)
        return laps.filter { lap in
            let residual = lap.lapDuration - model.predictedLapTime(atTyreAge: lap.tyreAge)
            return abs(residual - mean) <= 2 * stdDev
        }
    }

    // MARK: - Linear regression

    static func linearRegression(_ laps: [AnnotatedLap]) -> LinearDegradationModel? {
        guard laps.count >= 2 else { return nil }
        let n = Double(laps.count)
        let x = laps.map { Double($0.tyreAge) }
        let y = laps.map { $0.lapDuration }
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return nil }
        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n
        return LinearDegradationModel(baseLapTime: intercept, degradationRate: slope)
    }

    // MARK: - Build

    static func build(
        from laps: [AnnotatedLap],
        type: DegradationModelType = .linear
    ) -> DegradationModel? {
        // Pass 1 — hard filter
        let hardFiltered = hardFilter(laps)
        guard hardFiltered.count >= 2 else { return nil }

        switch type {
        case .linear:
            // Pass 2 — initial fit
            guard let initialModel = linearRegression(hardFiltered) else { return nil }
            // Pass 3 — soft filter using initial fit
            let softFiltered = softFilter(hardFiltered, model: initialModel)
            guard softFiltered.count >= 2 else { return initialModel }
            // Pass 4 — refit on clean data
            return linearRegression(softFiltered) ?? initialModel
        }
    }
}
