//
//  RacePaceViewModel.swift
//  LiveF1
//
//  Created by Riley Koo on 7/5/26.
//

import Combine
import Foundation

@MainActor
class RacePaceViewModel: ObservableObject {
    let session: F1PredictorSession

    @Published var driverStats: [DriverPaceStats] = []
    @Published var isLoading = false
    @Published var error: String?

    init(session: F1PredictorSession) {
        self.session = session
    }

    func load(existingLaps: [F1Lap]? = nil) async {
        isLoading = true
        error = nil
        do {
            let laps: [F1Lap]
            if let existingLaps {
                laps = existingLaps
            } else {
                laps = try await F1LapParser.fetchLive(sessionKey: "\(session.sessionKey)")
            }
            computeStats(from: laps)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func computeStats(from laps: [F1Lap]) {
        let byDriver = Dictionary(grouping: laps.filter { !$0.isPitOutLap && $0.lapDuration != nil },
                                   by: \.driverNumber)

        let rawStats: [DriverPaceStats] = byDriver.compactMap { driver, laps in
            let raw = laps.compactMap(\.lapDuration)
            let filtered = DriverPaceStats.filteringOutliers(raw)
            guard filtered.count >= 3 else { return nil }
            return DriverPaceStats(driverNumber: driver, durations: filtered)
        }

        // Session-wide fastest single lap across all drivers = 100% baseline
        guard let fastestOverall = rawStats.compactMap(\.durations.first).min() else {
            driverStats = []
            return
        }

        driverStats = rawStats
            .map { $0.asPercent(of: fastestOverall) }
            .sorted { $0.median < $1.median }
    }
}
