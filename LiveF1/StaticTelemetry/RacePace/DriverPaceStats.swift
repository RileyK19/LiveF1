//
//  DriverPaceStats.swift
//  LiveF1
//
//  Created by Riley Koo on 7/5/26.
//

struct DriverPaceStats: Identifiable {
    let driverNumber: Int
    let durations: [Double] // seconds, sorted ascending, outliers already removed

    var id: Int { driverNumber }
    var min: Double { durations.first ?? 0 }
    var max: Double { durations.last ?? 0 }
    var median: Double { Self.percentile(durations, 0.5) }
    var q1: Double { Self.percentile(durations, 0.25) }
    var q3: Double { Self.percentile(durations, 0.75) }

    static func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let idx = p * Double(sorted.count - 1)
        let lower = Int(idx.rounded(.down)), upper = Int(idx.rounded(.up))
        if lower == upper { return sorted[lower] }
        let frac = idx - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * frac
    }

    static func filteringOutliers(_ values: [Double]) -> [Double] {
        let sorted = values.sorted()
        guard sorted.count >= 4 else { return sorted }
        let q1 = percentile(sorted, 0.25), q3 = percentile(sorted, 0.75)
        let upperBound = q3 + 1.5 * (q3 - q1)
        return sorted.filter { $0 <= upperBound }
    }

    /// Convert this stat block into % of a reference time (typically the session's fastest lap)
    func asPercent(of reference: Double) -> DriverPaceStats {
        DriverPaceStats(driverNumber: driverNumber, durations: durations.map { ($0 / reference) * 100 })
    }
}
