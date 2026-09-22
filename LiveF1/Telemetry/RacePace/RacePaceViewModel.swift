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
    @Published var fastestLapTime: Double = 0
    @Published var racePaceByLap: [Int: [DriverPaceStats]] = [:]

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
            computeRacePaceByLap(from: laps)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func computeStats(from laps: [F1Lap]) {
        let result = RacePaceCalculator.overallStats(from: laps)
        driverStats = result.stats
        fastestLapTime = result.fastestLapTime
    }
    
//    private func computeStats(from laps: [F1Lap]) {
//        let byDriver = Dictionary(grouping: laps.filter { !$0.isPitOutLap && $0.lapDuration != nil }, by: \.driverNumber)
//
//        let rawStats: [DriverPaceStats] = byDriver.compactMap { driver, laps in
//            let raw = laps.compactMap(\.lapDuration)
//            let filtered = DriverPaceStats.filteringOutliers(raw)
//            guard filtered.count >= 3 else { return nil }
//            return DriverPaceStats(driverNumber: driver, durations: filtered)
//        }
//
//        guard let fastestOverall = rawStats.compactMap(\.durations.first).min() else {
//            driverStats = []
//            return
//        }
//
//        fastestLapTime = fastestOverall   // NEW: store it
//
//        driverStats = rawStats
//            .map { $0.asPercent(of: fastestOverall) }
//            .sorted { $0.median < $1.median }
//    }
    
    private func computeRacePaceByLap(
        from laps: [F1Lap],
        windowSize: Int = 5
    ) {
        racePaceByLap = [:]
        
        let validLaps = laps
            .filter { !$0.isPitOutLap && $0.lapDuration != nil && $0.lapNumber > 0 }
            .sorted { $0.lapNumber < $1.lapNumber }

        var durationsByDriver: [Int: [TimeInterval]] = [:]

        for lap in validLaps {
            guard let duration = lap.lapDuration else { continue }

            durationsByDriver[lap.driverNumber, default: []].append(duration)

            for driver in Array(durationsByDriver.keys) {
                if let durations = durationsByDriver[driver],
                   durations.count > windowSize {
                    durationsByDriver[driver] = Array(durations.suffix(windowSize))
                }
            }

            let stats: [DriverPaceStats] = durationsByDriver.compactMap {
                driver, durations in

                let filtered = DriverPaceStats.filteringOutliers(durations)

                guard filtered.count >= 3 else { return nil }

                return DriverPaceStats(
                    driverNumber: driver,
                    durations: filtered
                )
            }
            
            guard let fastest = stats.compactMap(\.durations.first).min(),
                  fastest.isFinite, fastest > 0
            else {
                continue
            }

            racePaceByLap[lap.lapNumber] = stats
                .map { $0.asPercent(of: fastest) }
                .sorted { $0.median < $1.median }
        }
    }



}
