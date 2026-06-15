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
