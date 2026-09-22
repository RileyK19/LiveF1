//
//  RacePaceCalculator.swift
//  Redline
//
//  Created by Riley Koo on 9/17/26.
//

import Foundation

enum RacePaceCalculator {

    /// Median pace (as % of the fastest driver) across every valid lap in the race so far.
    static func overallStats(from laps: [F1Lap]) -> (stats: [DriverPaceStats], fastestLapTime: Double) {
        let byDriver = Dictionary(grouping: laps.filter { !$0.isPitOutLap && $0.lapDuration != nil }, by: \.driverNumber)

        let rawStats: [DriverPaceStats] = byDriver.compactMap { driver, laps in
            let raw = laps.compactMap(\.lapDuration)
            let filtered = DriverPaceStats.filteringOutliers(raw)
            guard filtered.count >= 3 else { return nil }
            return DriverPaceStats(driverNumber: driver, durations: filtered)
        }

        guard let fastestOverall = rawStats.compactMap(\.durations.first).min() else {
            return ([], 0)
        }

        let stats = rawStats
            .map { $0.asPercent(of: fastestOverall) }
            .sorted { $0.median < $1.median }

        return (stats, fastestOverall)
    }

    /// Median pace over just the last `windowSize` valid laps per driver — "recent form" /
    /// "who's quickest right now" as opposed to the whole-race picture.
    static func recentStats(
        from laps: [F1Lap],
        windowSize: Int = 5
    ) -> (stats: [DriverPaceStats], fastestLapTime: Double, asOfLap: Int)? {
        let validLaps = laps
            .filter { !$0.isPitOutLap && $0.lapDuration != nil && $0.lapNumber > 0 }
            .sorted { $0.lapNumber < $1.lapNumber }

        guard let asOfLap = validLaps.map(\.lapNumber).max() else { return nil }

        let byDriver = Dictionary(grouping: validLaps, by: \.driverNumber)

        let rawStats: [DriverPaceStats] = byDriver.compactMap { driver, laps in
            let recent = laps.suffix(windowSize).compactMap(\.lapDuration)
            let filtered = DriverPaceStats.filteringOutliers(recent)
            guard filtered.count >= 3 else { return nil }
            return DriverPaceStats(driverNumber: driver, durations: filtered)
        }

        guard let fastest = rawStats.compactMap(\.durations.first).min(), fastest.isFinite, fastest > 0 else {
            return nil
        }

        let stats = rawStats
            .map { $0.asPercent(of: fastest) }
            .sorted { $0.median < $1.median }

        return (stats, fastest, asOfLap)
    }
}
