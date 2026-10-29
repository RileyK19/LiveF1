//
//  SessionSummaryView.swift
//  Redline
//

import SwiftUI
import Charts

// MARK: - Tunables

private enum Tuning {
    static let minStintLaps = 6          // only use runs of at least this many laps
    static let slowLapCut = 1.02         // drop laps >2% slower than their stint's median
    static let fuelGainPerLap = 0.04     // s/lap gained from fuel burn, added back
    static let lifeThreshold = 1.0       // seconds slower than fresh pace = "worn out"
    static let minDeg = 0.005            // below this s/lap, call it "no measurable wear"
}

// MARK: - Summary View

struct SessionSummaryView: View {
    @StateObject private var viewModel: RaceViewModel
    let session: F1PredictorSession

    init(session: F1PredictorSession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: { RaceViewModel(session: session) }())
    }

    var body: some View {
        let report = buildReport()

        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Loading session…")
                        .padding(.top, 40)
                } else if let report {
                    CrossoverCard(report: report)
                    ForEach(report.stats) { stats in
                        CompoundStatsCard(stats: stats, reference: report.reference)
                    }
                    Text("Fuel-corrected, driver-normalised, stints of \(Tuning.minStintLaps)+ laps from drivers who ran 2+ compounds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Not enough long-run data (need \(Tuning.minStintLaps)+ lap stints from drivers who ran 2+ compounds)")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
        .navigationTitle("Session Summary")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    // MARK: - Data

    private struct Row {
        let driver: Int
        let lapNumber: Int
        let tyreAge: Int
        let compound: String
        let time: Double      // fuel-corrected lap time
        let stintStart: Int
    }

    private func buildReport() -> PaceReport? {
        // 1. Long-run laps only, slow laps dropped, fuel-corrected
        var rows: [Row] = []
        for driver in viewModel.drivers {
            let laps = viewModel.annotatedLaps(for: driver)
            let byStint = Dictionary(grouping: laps) { lap in
                viewModel.stints.stint(for: driver, atLap: lap.lap.lapNumber)?.lapStart ?? -1
            }
            for (stintStart, stintLaps) in byStint where stintStart >= 0 && stintLaps.count >= Tuning.minStintLaps {
                let times = stintLaps.map { $0.lapDuration }.sorted()
                let median = times[times.count / 2]
                for lap in stintLaps where lap.lapDuration <= median * Tuning.slowLapCut {
                    let lapsRun = lap.lap.lapNumber - stintStart
                    rows.append(Row(
                        driver: driver,
                        lapNumber: lap.lap.lapNumber,
                        tyreAge: lap.tyreAge,
                        compound: lap.compound.rawValue,
                        time: lap.lapDuration + Tuning.fuelGainPerLap * Double(lapsRun),
                        stintStart: stintStart
                    ))
                }
            }
        }

        // 2. Keep only drivers who ran 2+ compounds (a one-compound driver tells us nothing about offsets)
        let compoundsPerDriver = Dictionary(grouping: rows, by: { $0.driver })
            .mapValues { Set($0.map { $0.compound }).count }
        rows = rows.filter { (compoundsPerDriver[$0.driver] ?? 0) >= 2 }
        guard !rows.isEmpty else { return nil }

        // 3. Driver baseline = mean of that driver's per-compound medians
        let baseline = Dictionary(grouping: rows, by: { $0.driver }).mapValues { driverRows -> Double in
            let meds = Dictionary(grouping: driverRows, by: { $0.compound }).values.map { r -> Double in
                let t = r.map { $0.time }.sorted()
                return t[t.count / 2]
            }
            return meds.reduce(0, +) / Double(meds.count)
        }

        // 4. Fit lap-time-delta vs tyre age per compound
        let stats: [CompoundStats] = Dictionary(grouping: rows, by: { $0.compound })
            .compactMap { (name, compoundRows) -> CompoundStats? in
                let points = compoundRows.map {
                    SessionPacePoint(driver: $0.driver, lapNumber: $0.lapNumber, tyreAge: $0.tyreAge,
                                     delta: $0.time - (baseline[$0.driver] ?? 0), stintStart: $0.stintStart)
                }

                // One slope per stint, so a long stint counts once
                let perStint = Array(Dictionary(grouping: points, by: { "\($0.driver)-\($0.stintStart)" }).values)
                let slopes: [Double] = perStint.compactMap { pts in
                    guard pts.count >= 4 else { return nil }
                    return linearFit(pts.map { Double($0.tyreAge) }, pts.map { $0.delta })?.slope
                }
                guard !slopes.isEmpty else { return nil }
                let slope = median(slopes)

                // One intercept per stint at that slope, then the median across stints
                let intercept = median(perStint.map { pts in
                    median(pts.map { $0.delta - slope * Double($0.tyreAge) })
                })

                return CompoundStats(
                    name: name,
                    points: points,
                    intercept: intercept,
                    slope: slope,
                    driverCount: Set(points.map { $0.driver }).count,
                    maxAge: points.map { $0.tyreAge }.max() ?? 0
                )
            }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let reference = stats.first(where: { $0.name.uppercased() == "MEDIUM" }) ?? stats.first
        else { return nil }
        return PaceReport(stats: stats, reference: reference)
    }

    private func linearFit(_ xs: [Double], _ ys: [Double]) -> (intercept: Double, slope: Double)? {
        let n = Double(xs.count)
        guard n >= 3 else { return nil }
        let mx = xs.reduce(0, +) / n
        let my = ys.reduce(0, +) / n
        let sxx = xs.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
        guard sxx > 0 else { return nil }
        let sxy = zip(xs, ys).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        let slope = sxy / sxx
        return (my - slope * mx, slope)
    }
    
    private func median(_ values: [Double]) -> Double {
        let s = values.sorted()
        return s[s.count / 2]
    }
}

// MARK: - Model

struct SessionPacePoint: Identifiable {
    var id: String { "\(driver)-\(lapNumber)" }
    let driver: Int
    let lapNumber: Int
    let tyreAge: Int
    let delta: Double    // seconds vs the driver's baseline, fuel-corrected
    let stintStart: Int
}

struct CrossPoint: Identifiable {
    var id: String { "\(compound)-\(lap)" }
    let compound: String
    let lap: Int
    let delta: Double    // cumulative seconds vs reference (negative = ahead)
}

struct CompoundStats: Identifiable {
    var id: String { name }
    let name: String
    let points: [SessionPacePoint]
    let intercept: Double   // fitted pace at age 0, seconds vs driver baseline
    let slope: Double       // seconds lost per lap of tyre age
    let driverCount: Int
    let maxAge: Int         // oldest tyre age actually observed

    var tyreLife: Int? {
        slope > Tuning.minDeg ? Int((Tuning.lifeThreshold / slope).rounded()) : nil
    }

    var lifeText: String {
        guard let life = tyreLife else { return "No measurable wear" }
        if life > maxAge + 3 { return "Beyond data (>\(maxAge) laps)" }
        return "~\(life) laps"
    }

    var color: Color {
        switch name.uppercased() {
        case "SOFT": return .red
        case "MEDIUM": return .yellow
        case "HARD": return .gray
        case "INTERMEDIATE": return .green
        case "WET": return .blue
        default: return .purple
        }
    }

    var sortOrder: Int {
        switch name.uppercased() {
        case "SOFT": return 0
        case "MEDIUM": return 1
        case "HARD": return 2
        case "INTERMEDIATE": return 3
        case "WET": return 4
        default: return 5
        }
    }
}

struct PaceReport {
    let stats: [CompoundStats]
    let reference: CompoundStats

    /// Cumulative time difference vs the reference after N laps on one set (no extrapolation past observed age)
    func crossoverPoints() -> [CrossPoint] {
        stats.flatMap { s -> [CrossPoint] in
            (1...max(1, s.maxAge)).map { n in
                let nd = Double(n)
                let delta = nd * (s.intercept - reference.intercept)
                    + (s.slope - reference.slope) * nd * (nd + 1) / 2
                return CrossPoint(compound: s.name, lap: n, delta: delta)
            }
        }
    }
}

// MARK: - Crossover Chart

private struct CrossoverCard: View {
    let report: PaceReport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cumulative time vs \(report.reference.name.capitalized)")
                .font(.headline)
            Text("Below 0 = ahead of the reference after N laps on one set")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart(report.crossoverPoints()) { p in
                LineMark(
                    x: .value("Laps", p.lap),
                    y: .value("Delta", p.delta),
                    series: .value("Compound", p.compound)
                )
                .foregroundStyle(by: .value("Compound", p.compound))
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartForegroundStyleScale(
                domain: report.stats.map { $0.name },
                range: report.stats.map { $0.color }
            )
            .chartXAxisLabel("Laps on tyre")
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let s = value.as(Double.self) {
                            Text(String(format: "%+.1fs", s)).font(.caption2.monospacedDigit())
                        }
                    }
                }
            }
            .frame(height: 240)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Per-compound Card

private struct CompoundStatsCard: View {
    let stats: CompoundStats
    let reference: CompoundStats

    private var isReference: Bool { stats.name == reference.name }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(stats.color).frame(width: 12, height: 12)
                Text(stats.name.capitalized).font(.headline)
                if isReference {
                    Text("reference").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(alignment: .top) {
                stat("Pace", isReference ? "—" : String(format: "%+.2fs", stats.intercept - reference.intercept))
                stat("Deg", String(format: "%.3f s/lap", stats.slope))
                stat("Usable life", stats.lifeText)
            }

            Chart {
                ForEach(stats.points) { p in
                    PointMark(
                        x: .value("Tyre Age", p.tyreAge),
                        y: .value("Delta", p.delta)
                    )
                    .foregroundStyle(stats.color.opacity(0.4))
                    .symbolSize(18)
                }
                ForEach([1, stats.maxAge], id: \.self) { age in
                    LineMark(
                        x: .value("Tyre Age", age),
                        y: .value("Fit", stats.intercept + stats.slope * Double(age)),
                        series: .value("Series", "Fit")
                    )
                    .foregroundStyle(.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartXAxisLabel("Tyre age (laps)")
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let s = value.as(Double.self) {
                            Text(String(format: "%+.1fs", s)).font(.caption2.monospacedDigit())
                        }
                    }
                }
            }
            .frame(height: 180)

            Text("\(stats.points.count) laps · \(stats.driverCount) drivers · up to age \(stats.maxAge)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
