//
//  RaceViewModel.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//


//  RaceViewModel.swift

import Foundation
import Combine

@MainActor
class RaceViewModel: ObservableObject {
    let session: F1PredictorSession

    @Published var laps: [F1Lap] = []
    @Published var stints: [F1PredictorStint] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    // Derived
    @Published var selectedDriverNumber: Int? = nil
    
    @Published var hypotheticalStints: [F1PredictorStint]? = nil
    
    @Published var comparisonDriverNumber: Int? = nil

    var stintsForComparisonDriver: [F1PredictorStint] {
        guard let driver = comparisonDriverNumber else { return stintsForSelectedDriver }
        return stints.stints(for: driver)
    }

    var comparisonAnnotatedLaps: [AnnotatedLap] {
        guard let driver = comparisonDriverNumber else { return annotatedLaps }
        let driverLaps = laps
            .filter { $0.driverNumber == driver && !$0.isPitOutLap && $0.lapDuration != nil }
            .sorted { $0.lapNumber < $1.lapNumber }
        return driverLaps.compactMap { lap in
            guard let duration = lap.lapDuration,
                  let stint = stints.stint(for: driver, atLap: lap.lapNumber),
                  let age = stints.tyreAge(for: driver, atLap: lap.lapNumber)
            else { return nil }
            return AnnotatedLap(lap: lap, tyreAge: age, compound: stint.compoundEnum, lapDuration: duration)
        }
    }
    
    var stintRegressionLines: [(stint: F1PredictorStint, model: DegradationModel, laps: [AnnotatedLap])] {
        guard let driver = selectedDriverNumber else { return [] }
        return stintsForSelectedDriver.compactMap { stint in
            guard let range = stint.lapRange else { return nil }
            let stintLaps = annotatedLaps.filter { range.contains($0.lap.lapNumber) }
            guard let model = DegradationModelFactory.build(from: stintLaps) else { return nil }
            return (stint, model, stintLaps)
        }
    }
    
    var trackEvolutionModel: TrackEvolutionCalculator.TrackEvolutionModel? {
        TrackEvolutionCalculator.build(from: laps)
    }

    var driverMedianLapTime: Double? {
        guard let driver = selectedDriverNumber else { return nil }
        let durations = laps
            .filter { $0.driverNumber == driver && !$0.isPitOutLap && $0.lapDuration != nil }
            .compactMap { $0.lapDuration }
            .sorted()
        guard !durations.isEmpty else { return nil }
        return durations[durations.count / 2]
    }

    var adjustedAnnotatedLaps: [AnnotatedLap] {
        guard let driver = selectedDriverNumber,
              let trackModel = trackEvolutionModel,
              let median = driverMedianLapTime
        else { return [] }

        return lapsForSelectedDriver.compactMap { lap in
            guard let stint = stints.stint(for: driver, atLap: lap.lapNumber),
                  let age = stints.tyreAge(for: driver, atLap: lap.lapNumber),
                  let adjusted = TrackEvolutionCalculator.adjustedDuration(
                      lap: lap,
                      driverMedian: median,
                      trackModel: trackModel
                  )
            else { return nil }
            return AnnotatedLap(
                lap: lap,
                tyreAge: age,
                compound: stint.compoundEnum,
                lapDuration: adjusted
            )
        }
    }

    var adjustedStintRegressionLines: [(stint: F1PredictorStint, model: DegradationModel, laps: [AnnotatedLap])] {
        guard let driver = selectedDriverNumber else { return [] }
        return stintsForSelectedDriver.compactMap { stint in
            guard let range = stint.lapRange else { return nil }
            let stintLaps = adjustedAnnotatedLaps.filter { range.contains($0.lap.lapNumber) }
            guard let model = DegradationModelFactory.build(from: stintLaps) else { return nil }
            return (stint, model, stintLaps)
        }
    }

    init(session: F1PredictorSession) {
        self.session = session
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            async let fetchedLaps = F1LapParser.fetchLive(sessionKey: "\(session.sessionKey)")
            async let fetchedStints = F1PredictorStintParser.fetch(sessionKey: "\(session.sessionKey)")
            let (l, s) = try await (fetchedLaps, fetchedStints)
            laps = l
            stints = s
            // Default to first driver
            selectedDriverNumber = drivers.first
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Derived properties

    var drivers: [Int] {
        Array(Set(laps.map { $0.driverNumber })).sorted()
    }

    var lapsForSelectedDriver: [F1Lap] {
        guard let driver = selectedDriverNumber else { return [] }
        return laps
            .filter { $0.driverNumber == driver && !$0.isPitOutLap && $0.lapDuration != nil }
            .sorted { $0.lapNumber < $1.lapNumber }
    }

    var stintsForSelectedDriver: [F1PredictorStint] {
        guard let driver = selectedDriverNumber else { return [] }
        return stints.stints(for: driver)
    }

    /// Laps annotated with tyre age and compound
    var annotatedLaps: [AnnotatedLap] {
        guard let driver = selectedDriverNumber else { return [] }
        return lapsForSelectedDriver.compactMap { lap in
            guard let duration = lap.lapDuration,
                  let stint = stints.stint(for: driver, atLap: lap.lapNumber),
                  let age = stints.tyreAge(for: driver, atLap: lap.lapNumber)
            else { return nil }
            return AnnotatedLap(
                lap: lap,
                tyreAge: age,
                compound: stint.compoundEnum,
                lapDuration: duration
            )
        }
    }
    
    // In your ViewModel

    func calculateTimeDeltaVsDriver(hypothetical: [F1PredictorStint]) -> Double? {
        guard let median = driverMedianLapTime,
              let trackModel = trackEvolutionModel
        else { return nil }

        let baseStints = comparisonDriverNumber != nil ? stintsForComparisonDriver : stintsForSelectedDriver
        let baseLaps   = comparisonDriverNumber != nil ? comparisonAnnotatedLaps  : annotatedLaps

        return StrategyCalculator.shared.timeDeltaVsDriver(
            hypothetical: hypothetical,
            baseStints: baseStints,
            median: median,
            trackModel: trackModel,
            baseLaps: baseLaps
        )
    }
}

// MARK: - AnnotatedLap

struct AnnotatedLap: Identifiable {
    var id: Int { lap.lapNumber }
    let lap: F1Lap
    let tyreAge: Int
    let compound: TyreCompound
    let lapDuration: Double

    var formattedLapTime: String { lap.formattedLapTime }
}
