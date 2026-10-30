//
//  SessionSummaryView.swift
//  Redline
//

import SwiftUI
import Charts

// MARK: - Tunables

private enum Tuning {
    static let minStintLaps = 5
    static let minKeptLaps = 3
    static let slowLapCut = 1.025
    static let limitedDataStints = 2
    static let fuelGainPerLap = 0.04
}

// MARK: - Model

private struct StintLap: Identifiable {
    var id: Int { age }
    let age: Int
    let time: Double   // fuel-corrected lap time
}

private struct StintSeries: Identifiable {
    let id: String
    let key: String        // "session-driver"
    let compound: String
    let laps: [StintLap]
    let length: Int

    var medianTime: Double { Self.median(laps.map { $0.time }) }

    /// Least-squares slope of lap time vs tyre age (s/lap). Nil if the age spread is too small.
    var slope: Double? {
        let xs = laps.map { Double($0.age) }
        let ys = laps.map { $0.time }
        guard let lo = xs.min(), let hi = xs.max(), hi - lo >= 3 else { return nil }
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n
        let my = ys.reduce(0, +) / n
        let sxx = xs.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
        guard sxx > 0 else { return nil }
        let sxy = zip(xs, ys).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        return sxy / sxx
    }

    static func median(_ v: [Double]) -> Double {
        guard !v.isEmpty else { return 0 }
        let s = v.sorted()
        return s[s.count / 2]
    }
}

private struct CompoundSummary: Identifiable {
    var id: String { name }
    let name: String
    let offset: Double     // seconds vs each driver's best run (median across stints)
    let slope: Double?     // s/lap (median across stints)
    let stints: Int
    let avgLength: Double
    let maxLength: Int
}

private func compoundOrder(_ name: String) -> Int {
    ["SOFT": 0, "MEDIUM": 1, "HARD": 2, "INTERMEDIATE": 3, "WET": 4][name.uppercased()] ?? 5
}

private func compoundColor(_ name: String) -> Color {
    switch name.uppercased() {
    case "SOFT": return .red
    case "MEDIUM": return .yellow
    case "HARD": return .gray
    case "INTERMEDIATE": return .green
    case "WET": return .blue
    default: return .purple
    }
}

// MARK: - Summary View

struct SessionSummaryView: View {
    @StateObject private var viewModel: MultiRaceViewModel
    let session: [F1PredictorSession]

    init(session: F1PredictorSession) {
        self.session = [session]
        _viewModel = StateObject(wrappedValue: { MultiRaceViewModel(session: session) }())
    }

    init(session: [F1PredictorSession]) {
        self.session = session
        _viewModel = StateObject(wrappedValue: { MultiRaceViewModel(sessions: session) }())
    }

    init(session: [MultiF1PredictorSession]) {
        self.session = session.flatMap { $0.sessions }
        _viewModel = StateObject(wrappedValue: { MultiRaceViewModel(sessions: session.flatMap { $0.sessions }) }())
    }

    // MARK: Data

    private func buildStints() -> [StintSeries] {
        var out: [StintSeries] = []
        for (sIdx, vm) in viewModel.wrapped.enumerated() {
            for driver in vm.drivers {
                let laps = vm.annotatedLaps(for: driver)
                let byStint = Dictionary(grouping: laps) { lap in
                    vm.stints.stint(for: driver, atLap: lap.lap.lapNumber)?.lapStart ?? -1
                }
                for (start, stintLaps) in byStint where start >= 0 && stintLaps.count >= Tuning.minStintLaps {
                    // fuel-correct each lap
                    let timed = stintLaps.sorted { $0.lap.lapNumber < $1.lap.lapNumber }.dropFirst().dropLast().map { lap in
                        (age: lap.tyreAge,
                         time: lap.lapDuration + Tuning.fuelGainPerLap * Double(lap.lap.lapNumber - start),
                         compound: lap.compound.rawValue)
                    }
                    // drop slow laps relative to this stint's own median
                    let times = timed.map { $0.time }.sorted()
                    let med = StintSeries.median(Array(times.prefix(max(3, times.count / 2))))
                    let kept = timed.filter { $0.time <= med * Tuning.slowLapCut }
                    guard kept.count >= Tuning.minKeptLaps, let compound = kept.first?.compound else { continue }

                    out.append(StintSeries(
                        id: "\(sIdx)-\(driver)-\(start)",
                        key: "\(sIdx)-\(driver)",
                        compound: compound,
                        laps: kept.map { StintLap(age: $0.age, time: $0.time) }
                            .sorted { $0.age < $1.age },
                        length: stintLaps.count
                    ))
                }
            }
        }
        return out
    }

    private func buildReport(_ stints: [StintSeries])
        -> (refs: [String: Double], summary: [CompoundSummary]) {

        // each driver's best stint median is their reference
        let byDriver = Dictionary(grouping: stints, by: \.key)
            let refs = Dictionary(grouping: stints, by: \.key).mapValues { ss -> Double in
                let meds = Dictionary(grouping: ss, by: \.compound).values.map { StintSeries.median($0.map(\.medianTime)) }
                return meds.reduce(0, +) / Double(meds.count)
            }
            
        // only drivers who ran 2+ compounds count for the summary
        let multi = Set(byDriver.filter { Set($0.value.map(\.compound)).count >= 2 }.keys)

        var summary = Dictionary(grouping: stints.filter { multi.contains($0.key) }, by: \.compound)
            .map { name, ss -> CompoundSummary in
                let offsets = ss.map { $0.medianTime - (refs[$0.key] ?? 0) }
                let slopes = ss.compactMap(\.slope)
                let lengths = ss.map(\.length)
                return CompoundSummary(
                    name: name,
                    offset: StintSeries.median(offsets),
                    slope: slopes.isEmpty ? nil : StintSeries.median(slopes),
                    stints: ss.count,
                    avgLength: Double(lengths.reduce(0, +)) / Double(lengths.count),
                    maxLength: lengths.max() ?? 0
                )
            }

        // always show the three dry compounds, even with no data
        for name in ["SOFT", "MEDIUM", "HARD"] where !summary.contains(where: { $0.name.uppercased() == name }) {
            summary.append(CompoundSummary(name: name, offset: 0, slope: nil, stints: 0, avgLength: 0, maxLength: 0))
        }
        summary.sort { compoundOrder($0.name) < compoundOrder($1.name) }

        return (refs, summary)
    }

    // MARK: Body

    var body: some View {
        let stints = buildStints()
        let report = buildReport(stints)

        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Loading session…").padding(.top, 40)
                } else if stints.isEmpty {
                    Text("Not enough long-run data")
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                } else {
                    StintChart(stints: stints, refs: report.refs)
                    SummaryTable(rows: report.summary)
                    Text("Fuel-corrected, stints of \(Tuning.minStintLaps)+ laps, shown vs each driver's best run. Summary uses drivers who ran 2+ compounds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationTitle("Session Summary • \(viewModel.sessions[0].location)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

// MARK: - Stint Chart

private struct StintChart: View {
    let stints: [StintSeries]
    let refs: [String: Double]
    
    private struct TrendPoint: Identifiable {
        var id: String { "\(compound)-\(age)" }
        let compound: String
        let age: Int
        let delta: Double
    }

    private var trend: [TrendPoint] {
        var groups: [String: [Double]] = [:]
        for s in stints {
            for l in s.laps {
                groups["\(s.compound)|\(l.age)", default: []].append(l.time - (refs[s.key] ?? 0))
            }
        }
        return groups.compactMap { key, v in
            guard v.count >= 4 else { return nil }
            let parts = key.split(separator: "|")
            return TrendPoint(compound: String(parts[0]), age: Int(parts[1]) ?? 0, delta: StintSeries.median(v))
        }
        .sorted { $0.age < $1.age }
    }

    var body: some View {
        let names = Array(Set(stints.map { $0.compound }))
            .sorted { compoundOrder($0) < compoundOrder($1) }

        VStack(alignment: .leading, spacing: 8) {
            Text("Lap time vs tyre age")
                .font(.headline)
            Text("Each line is one stint, relative to that driver's best run (0 = their best)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart {
                ForEach(stints) { stint in
                    ForEach(stint.laps) { lap in
                        PointMark(x: .value("Tyre age", lap.age),
                                  y: .value("vs driver avg (s)", lap.time - (refs[stint.key] ?? 0)))
                            .foregroundStyle(by: .value("Compound", stint.compound))
                            .symbolSize(14)
                            .opacity(0.2)
                    }
                }
                ForEach(trend) { p in
                    LineMark(x: .value("Tyre age", p.age),
                             y: .value("Median (s)", p.delta),
                             series: .value("Trend", p.compound))
                        .foregroundStyle(by: .value("Compound", p.compound))
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartForegroundStyleScale(domain: names, range: names.map { compoundColor($0) })
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
            .chartYScale(domain: -4...6)
            .frame(height: 300)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Summary Table

private struct SummaryTable: View {
    let rows: [CompoundSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Compound summary")
                .font(.headline)

            if rows.isEmpty {
                Text("No drivers ran 2+ compounds in long runs yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    header("Compound", alignment: .leading)
                    header("Pace")
                    header("Deg")
                    header("Stints")
                }

                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            HStack(spacing: 6) {
                                Circle().fill(compoundColor(row.name)).frame(width: 10, height: 10)
                                Text(row.name.capitalized).font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if row.stints == 0 {
                                Text("No long runs")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                cell(String(format: "%+.2fs", row.offset))
                                cell(row.slope.map { String(format: "%.3f", $0) } ?? "—")
                                cell("\(row.stints)")
                            }
                        }
                        if row.stints > 0 {
                            Text("avg run \(Int(row.avgLength.rounded())) laps · longest \(row.maxLength)"
                                 + (row.stints < Tuning.limitedDataStints ? " · limited data" : ""))
                                .font(.caption2)
                                .foregroundStyle(row.stints < Tuning.limitedDataStints ? .orange : .secondary)
                        }
                    }
                }
                
                Text("Pace = median stint pace vs the driver's best run. Deg = s/lap lost per lap of tyre age.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private func header(_ text: String, alignment: Alignment = .trailing) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func cell(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.monospacedDigit())
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

//import SwiftUI
//import Charts
//
//// MARK: - Tunables
//
//private enum Tuning {
//    static let minStintLaps = 6          // only use runs of at least this many laps
//    static let slowLapCut = 1.02         // drop laps >2% slower than their stint's median
//    static let fuelGainPerLap = 0.04     // s/lap gained from fuel burn, added back
//    static let lifeThreshold = 1.0       // seconds slower than fresh pace = "worn out"
//    static let minDeg = 0.005            // below this s/lap, call it "no measurable wear"
//    static let fastLapCut = 1.025    // keep laps within 2.5% of the stint's fast reference
//    static let stintPaceCut = 1.06   // drop stints >4% slower than that driver's best long run
//    static let minKeptLaps = 4
//    static let minRunLaps = 5      // was 8
//    static let minRunStints = 3    // keep
//}
//
//// MARK: - Summary View
//
//struct SessionSummaryView: View {
//    @StateObject private var viewModel: MultiRaceViewModel
//    let session: [F1PredictorSession]
//
//    init(session: F1PredictorSession) {
//        self.session = [session]
//        _viewModel = StateObject(wrappedValue: { MultiRaceViewModel(session: session) }())
//    }
//
//    init(session: [F1PredictorSession]) {
//        self.session = session
//        _viewModel = StateObject(wrappedValue: { MultiRaceViewModel(sessions: session) }())
//    }
//
//    init(session: [MultiF1PredictorSession]) {
//        self.session = session.flatMap { $0.sessions }
//        _viewModel = StateObject(wrappedValue: { MultiRaceViewModel(sessions: session.flatMap { $0.sessions }) }())
//    }
//
//    struct MedianPoint: Identifiable {
//        var id: String { "\(compound)-\(age)" }
//        let compound: String
//        let age: Int
//        let time: Double
//        let n: Int
//    }
//
//    struct LapDot: Identifiable {
//        let id = UUID()
//        let compound: String
//        let age: Int
//        let time: Double
//    }
//
//    // inside SessionSummaryView
//    private func buildMedians() -> [MedianPoint] {
//        var valid: [(compound: String, age: Int, time: Double)] = []
//        for vm in viewModel.wrapped {
//            var laps: [(compound: String, age: Int, time: Double)] = []
//            for driver in vm.drivers {
//                for lap in vm.annotatedLaps(for: driver) {
//                    laps.append((lap.compound.rawValue, lap.tyreAge, lap.lapDuration))
//                }
//            }
//            guard let fastest = laps.map({ $0.time }).min() else { continue }
//            valid += laps.filter { $0.time <= fastest * 1.07 }
//        }
//
//        let grouped = Dictionary(grouping: valid, by: { "\($0.compound)|\($0.age)" })
//        var out: [MedianPoint] = []
//        for (_, laps) in grouped where laps.count >= 5 {
//            let t = laps.map { $0.time }.sorted()
//            out.append(MedianPoint(compound: laps[0].compound, age: laps[0].age,
//                                   time: t[t.count / 2], n: laps.count))
//        }
//        return out.sorted { $0.compound == $1.compound ? $0.age < $1.age : $0.compound < $1.compound }
//    }
//
//    private func buildChartData() -> (dots: [LapDot], medians: [MedianPoint]) {
//        var valid: [LapDot] = []
//        for vm in viewModel.wrapped {
//            var laps: [LapDot] = []
//            for driver in vm.drivers {
//                for lap in vm.annotatedLaps(for: driver) {
//                    laps.append(LapDot(compound: lap.compound.rawValue, age: lap.tyreAge, time: lap.lapDuration))
//                }
//            }
//            guard let fastest = laps.map({ $0.time }).min() else { continue }
//            valid += laps.filter { $0.time <= fastest * 1.07 }
//        }
//
//        let grouped = Dictionary(grouping: valid, by: { "\($0.compound)|\($0.age)" })
//        var medians: [MedianPoint] = []
//        for (_, laps) in grouped where laps.count >= 5 {
//            let t = laps.map { $0.time }.sorted()
//            medians.append(MedianPoint(compound: laps[0].compound, age: laps[0].age,
//                                       time: t[t.count / 2], n: laps.count))
//        }
//        medians.sort { $0.compound == $1.compound ? $0.age < $1.age : $0.compound < $1.compound }
//        return (valid, medians)
//    }
//
//    var body: some View {
//        let points = buildMedians()
//        let data = buildChartData()
//
//        ScrollView {
//            VStack(spacing: 20) {
//                if viewModel.isLoading {
//                    ProgressView("Loading session…").padding(.top, 40)
//                } else if !points.isEmpty, !data.medians.isEmpty {
//                    MedianChart(dots: data.dots, points: data.medians)
//                    Text("Median lap time per tyre age, laps within 107% of each session's fastest. Ages with fewer than 5 laps hidden.")
//                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
//                } else {
//                    Text("Not enough valid laps")
//                        .foregroundStyle(.secondary).padding(.top, 40)
//                }
//            }
//            .padding()
//        }
//        .navigationTitle("Session Summary")
//        .navigationBarTitleDisplayMode(.inline)
//        .task { await viewModel.load() }
//    }
//
//    private struct MedianChart: View {
//        let dots: [LapDot]
//        let points: [MedianPoint]
//        private func color(_ name: String) -> Color {
//            switch name.uppercased() {
//            case "SOFT": return .red
//            case "MEDIUM": return .yellow
//            case "HARD": return .gray
//            case "INTERMEDIATE": return .green
//            case "WET": return .blue
//            default: return .purple
//            }
//        }
//
//        var body: some View {
//            let names = Array(Set(points.map { $0.compound })).sorted()
//            Chart {
//                ForEach(dots) { d in
//                    PointMark(x: .value("Tyre age", d.age),
//                              y: .value("Lap (s)", d.time))
//                    .foregroundStyle(color(d.compound).opacity(0.25))
//                    .symbolSize(12)
//                }
//                ForEach(points) { p in
//                    LineMark(x: .value("Tyre age", p.age),
//                             y: .value("Median lap (s)", p.time),
//                             series: .value("Compound", p.compound))
//                    .foregroundStyle(by: .value("Compound", p.compound))
//                    PointMark(x: .value("Tyre age", p.age),
//                              y: .value("Median lap (s)", p.time))
//                    .foregroundStyle(by: .value("Compound", p.compound))
//                    .symbolSize(Double(p.n) * 3)
//                }
//            }
//            .chartForegroundStyleScale(domain: names, range: names.map { color($0) })
//            .chartXAxisLabel("Tyre age (laps)")
//            .chartYScale(domain: .automatic(includesZero: false))
//            .frame(height: 300)
//            .padding()
//            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
//        }
//    }
//}

//    var body: some View {
//        let report = buildReport()
//
//        ScrollView {
//            VStack(spacing: 20) {
//                if viewModel.isLoading {
//                    ProgressView("Loading session…")
//                        .padding(.top, 40)
//                } else if let report {
//                    CrossoverCard(report: report)
//                    ForEach(report.stats) { stats in
//                        CompoundStatsCard(stats: stats, reference: report.reference)
//                    }
//                    Text("Fuel-corrected, driver-normalised, stints of \(Tuning.minStintLaps)+ laps from drivers who ran 2+ compounds.")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                        .multilineTextAlignment(.center)
//                } else {
//                    Text("Not enough long-run data (need \(Tuning.minStintLaps)+ lap stints from drivers who ran 2+ compounds)")
//                        .foregroundStyle(.secondary)
//                        .multilineTextAlignment(.center)
//                        .padding(.top, 40)
//                }
//            }
//            .padding()
//        }
//        .navigationTitle("Session Summary")
//        .navigationBarTitleDisplayMode(.inline)
//        .task { await viewModel.load() }
//    }

    // MARK: - Data

//    private struct Row {
//        let session: Int
//        let driver: Int
//        let lapNumber: Int
//        let tyreAge: Int
//        let compound: String
//        let time: Double      // fuel-corrected lap time
//        let stintStart: Int
//        var key: String { "\(session)-\(driver)" }
//        let inRun: Bool
//    }
//    
//    private struct Candidate {
//        let stintStart: Int
//        let laps: [(lap: AnnotatedLap, time: Double)]   // time is fuel-corrected
//        let ref: Double                                  // the stint's fast reference pace
//    }
//
//    private func fastReference(_ times: [Double]) -> Double {
//        let s = times.sorted()
//        return median(Array(s.prefix(max(3, s.count / 4))))
//    }
//    
//    /// Lap numbers of the longest stretch of consecutive laps all within the fast cut.
//    private func longestFastRun(_ laps: [(lap: AnnotatedLap, time: Double)], ref: Double) -> Set<Int> {
//        let sorted = laps.sorted { $0.lap.lap.lapNumber < $1.lap.lap.lapNumber }
//        var best: [Int] = []
//        var cur: [Int] = []
//        for l in sorted {
//            let n = l.lap.lap.lapNumber
//            if l.time <= ref * Tuning.fastLapCut {
//                if let last = cur.last, last == n - 1 { cur.append(n) } else { cur = [n] }
//                if cur.count > best.count { best = cur }
//            } else {
//                cur = []
//            }
//        }
//        return best.count >= Tuning.minRunLaps ? Set(best) : []
//    }
//
//    private func buildReport() -> PaceReport? {
////        print("wrapped:", viewModel.wrapped.count)
////        for (i, vm) in viewModel.wrapped.enumerated() {
////            print(i, "error:", vm.error ?? "none", "drivers:", vm.drivers.count)
////        }
//        
//        // 1. Long-run laps only, slow laps dropped, fuel-corrected
////        var rows: [Row] = []
////        for (sIdx, vm) in viewModel.wrapped.enumerated() {
////            for driver in vm.drivers {
////                let laps = vm.annotatedLaps(for: driver)
////                let byStint = Dictionary(grouping: laps) { lap in
////                    vm.stints.stint(for: driver, atLap: lap.lap.lapNumber)?.lapStart ?? -1
////                }
////                for (stintStart, stintLaps) in byStint where stintStart >= 0 && stintLaps.count >= Tuning.minStintLaps {
////                    let times = stintLaps.map { $0.lapDuration }.sorted()
////                    let median = times[times.count / 2]
////                    for lap in stintLaps where lap.lapDuration <= median * Tuning.slowLapCut {
////                        let lapsRun = lap.lap.lapNumber - stintStart
////                        rows.append(Row(
////                            session: sIdx,
////                            driver: driver,
////                            lapNumber: lap.lap.lapNumber,
////                            tyreAge: lap.tyreAge,
////                            compound: lap.compound.rawValue,
////                            time: lap.lapDuration + Tuning.fuelGainPerLap * Double(lapsRun),
////                            stintStart: stintStart
////                        ))
////                    }
////                }
////            }
////        }
//        
//        var rows: [Row] = []
//        var nStints = 0, nLong = 0, nPace = 0, nKept = 0
//        for (sIdx, vm) in viewModel.wrapped.enumerated() {
//            for driver in vm.drivers {
//                let laps = vm.annotatedLaps(for: driver)
//                let byStint = Dictionary(grouping: laps) { lap in
//                    vm.stints.stint(for: driver, atLap: lap.lap.lapNumber)?.lapStart ?? -1
//                }
//                nStints += byStint.count
//
//                // Pass A: describe each long-enough stint by its fast pace
//                var candidates: [Candidate] = []
//                for (stintStart, stintLaps) in byStint where stintStart >= 0 && stintLaps.count >= Tuning.minStintLaps {
//                    var timed: [(lap: AnnotatedLap, time: Double)] = []
//                    for lap in stintLaps {
//                        let lapsRun = lap.lap.lapNumber - stintStart
//                        let corrected = lap.lapDuration + Tuning.fuelGainPerLap * Double(lapsRun)
//                        timed.append((lap: lap, time: corrected))
//                    }
//                    let ref = fastReference(timed.map { $0.time })
//                    candidates.append(Candidate(stintStart: stintStart, laps: timed, ref: ref))
//                }
//                nLong += candidates.count
//                guard let bestRef = candidates.map({ $0.ref }).min() else { continue }
//
//                // Pass B: drop junk stints, then drop slow laps inside the survivors
//                for c in candidates where c.ref <= bestRef * Tuning.stintPaceCut {
//                    nPace += 1
//                    let kept = c.laps.filter { $0.time <= c.ref * Tuning.fastLapCut }
////                    print("cand laps:", c.laps.count, "kept:", kept.count, "ref:", String(format: "%.1f", c.ref))
////                    if c.laps.count >= 14 && kept.count <= 5 {
////                        let line = c.laps.sorted { $0.lap.lap.lapNumber < $1.lap.lap.lapNumber }
////                            .map { String(format: "%.1f", $0.time) }.joined(separator: " ")
////                        print("ref \(String(format: "%.1f", c.ref)):", line)
////                    }
//                    
//                    let runLaps = longestFastRun(c.laps, ref: c.ref)
//                    
//                    let sortedLaps = c.laps.sorted { $0.lap.lap.lapNumber < $1.lap.lap.lapNumber }
//                    var best = 0, cur = 0, prev = -99
//                    for l in sortedLaps {
//                        let n = l.lap.lap.lapNumber
//                        if l.time <= c.ref * Tuning.fastLapCut {
//                            cur = (n == prev + 1) ? cur + 1 : 1
//                            best = max(best, cur)
//                        } else { cur = 0 }
//                        prev = n
//                    }
//                    print("longest run:", best, "of", c.laps.count, "laps, ref", String(format: "%.1f", c.ref))
//                    
//                    guard kept.count >= Tuning.minKeptLaps else { continue }
//                    nKept += 1
//                    for k in kept {
//                        rows.append(Row(
//                            session: sIdx,
//                            driver: driver,
//                            lapNumber: k.lap.lap.lapNumber,
//                            tyreAge: k.lap.tyreAge,
//                            compound: k.lap.compound.rawValue,
//                            time: k.time,
//                            stintStart: c.stintStart,
//                            inRun: runLaps.contains(k.lap.lap.lapNumber)
//                        ))
//                    }
//                }
//            }
//        }
//        print("stints:", nStints, "long:", nLong, "pace ok:", nPace, "kept:", nKept, "rows:", rows.count)
//        
////        let perSession = Dictionary(grouping: rows, by: { $0.session }).mapValues { $0.count }
////        print("after stint filter:", rows.count, "per session:", perSession)
//        
//        var gaps: [String: [Double]] = [:]
//        for (_, rs) in Dictionary(grouping: rows, by: { $0.key }) {
//            let byC = Dictionary(grouping: rs.filter { $0.tyreAge <= 8 }, by: { $0.compound.uppercased() })
//            guard let m = byC["MEDIUM"], m.count >= 3 else { continue }
//            let mMed = fastQuarter(m.map { $0.time })
//            for (c, cr) in byC where c != "MEDIUM" && cr.count >= 3 {
//                gaps[c, default: []].append(fastQuarter(cr.map { $0.time }) - mMed)
//            }
//        }
//        for (c, g) in gaps {
//            print("gap vs MEDIUM", c, "n:", g.count, "median:", String(format: "%.2f", fastQuarter(g)),
//                  g.sorted().map { String(format: "%.2f", $0) })
//        }
//
//        // 2. Keep only drivers who ran 2+ compounds (a one-compound driver tells us nothing about offsets)
//        let compoundsPerDriver = Dictionary(grouping: rows, by: { $0.key })
//            .mapValues { Set($0.map { $0.compound }).count }
//        rows = rows.filter { (compoundsPerDriver[$0.key] ?? 0) >= 2 }
//        guard !rows.isEmpty else { return nil }
//
//        let baseline = Dictionary(grouping: rows, by: { $0.key }).mapValues { driverRows -> Double in
//            let meds = Dictionary(grouping: driverRows, by: { $0.compound }).values.map { r -> Double in
//                let t = r.map { $0.time }.sorted()
//                return t[t.count / 2]
//            }
//            return meds.reduce(0, +) / Double(meds.count)
//        }
//        
////        print("after 2+ compound filter:", rows.count)
//
//        // 4. Fit lap-time-delta vs tyre age per compound
//        let stats: [CompoundStats] = Dictionary(grouping: rows, by: { $0.compound })
//            .compactMap { (name, compoundRows) -> CompoundStats? in
//                let points: [SessionPacePoint] = compoundRows.map { (r: Row) -> SessionPacePoint in
//                    let base: Double = baseline[r.key] ?? 0
//                    return SessionPacePoint(
//                        driver: r.driver,
//                        lapNumber: r.lapNumber,
//                        tyreAge: r.tyreAge,
//                        delta: r.time - base,
//                        stintStart: r.stintStart,
//                        session: r.session,
//                        inRun: r.inRun
//                    )
//                }
//
//                let key = { (p: SessionPacePoint) -> String in "\(p.session)-\(p.driver)-\(p.stintStart)" }
//
//                // Degradation: only from long consecutive runs
//                let runGroups = Array(Dictionary(grouping: points.filter { $0.inRun }, by: key).values)
//                let slopes: [Double] = runGroups.compactMap { pts in
//                    theilSen(pts.map { Double($0.tyreAge) }, pts.map { $0.delta })
//                }
//                let hasDeg = slopes.count >= Tuning.minRunStints
//                let slope = hasDeg ? median(slopes) : 0
//
//                // Pace: every kept push lap
//                let perStint = Array(Dictionary(grouping: points, by: key).values)
//                let intercept = median(perStint.map { pts in
//                    median(pts.map { $0.delta - slope * Double($0.tyreAge) })
//                })
//
//                return CompoundStats(
//                    name: name,
//                    points: points,
//                    intercept: intercept,
//                    slope: slope,
//                    driverCount: Set(points.map { $0.driver }).count,
//                    maxAge: points.map { $0.tyreAge }.max() ?? 0,
//                    hasDeg: hasDeg,
//                    runStints: runGroups.count
//                )
//            }
//            .sorted { $0.sortOrder < $1.sortOrder }
//        
////        for s in stats {
////            let perStint = Dictionary(grouping: s.points, by: { "\($0.session)-\($0.driver)-\($0.stintStart)" })
////            let slopes = perStint.values.compactMap { pts -> Double? in
////                guard pts.count >= 5 else { return nil }
////                let ages = pts.map { $0.tyreAge }
////                guard let lo = ages.min(), let hi = ages.max(), hi - lo >= 5 else { return nil }
////                return theilSen(pts.map { Double($0.tyreAge) }, pts.map { $0.delta })
////            }.sorted()
////            print(s.name, "stints:", slopes.count, "slopes:", slopes.map { String(format: "%.3f", $0) },
////                  "intercept:", String(format: "%.2f", s.intercept), "maxAge:", s.maxAge)
////        }
//
//        guard let reference = stats.first(where: { $0.name.uppercased() == "MEDIUM" }) ?? stats.first
//        else { return nil }
//        return PaceReport(stats: stats, reference: reference)
//    }
//
//    private func linearFit(_ xs: [Double], _ ys: [Double]) -> (intercept: Double, slope: Double)? {
//        let n = Double(xs.count)
//        guard n >= 3 else { return nil }
//        let mx = xs.reduce(0, +) / n
//        let my = ys.reduce(0, +) / n
//        let sxx = xs.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
//        guard sxx > 0 else { return nil }
//        let sxy = zip(xs, ys).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
//        let slope = sxy / sxx
//        return (my - slope * mx, slope)
//    }
//    
//    private func median(_ values: [Double]) -> Double {
//        let s = values.sorted()
//        return s[s.count / 2]
//    }
//    
//    private func theilSen(_ xs: [Double], _ ys: [Double]) -> Double? {
//        var pairwise: [Double] = []
//        for i in 0..<xs.count {
//            for j in (i + 1)..<xs.count where xs[j] != xs[i] {
//                pairwise.append((ys[j] - ys[i]) / (xs[j] - xs[i]))
//            }
//        }
//        return pairwise.isEmpty ? nil : median(pairwise)
//    }
//    
//    func fastQuarter(_ xs: [Double]) -> Double {
//        let s = xs.sorted()
//        return median(Array(s.prefix(max(3, s.count / 4))))
//    }
//}

// MARK: - Model

//struct SessionPacePoint: Identifiable {
//    var id: String { "\(session)-\(driver)-\(lapNumber)" }
//    let driver: Int
//    let lapNumber: Int
//    let tyreAge: Int
//    let delta: Double    // seconds vs the driver's baseline, fuel-corrected
//    let stintStart: Int
//    let session: Int
//    let inRun: Bool
//}
//
//struct CrossPoint: Identifiable {
//    var id: String { "\(compound)-\(lap)" }
//    let compound: String
//    let lap: Int
//    let delta: Double    // cumulative seconds vs reference (negative = ahead)
//}
//
//struct CompoundStats: Identifiable {
//    var id: String { name }
//    let name: String
//    let points: [SessionPacePoint]
//    let intercept: Double   // fitted pace at age 0, seconds vs driver baseline
//    let slope: Double       // seconds lost per lap of tyre age
//    let driverCount: Int
//    let maxAge: Int         // oldest tyre age actually observed
//    let hasDeg: Bool
//    let runStints: Int
//
//    var tyreLife: Int? {
//        hasDeg && slope > Tuning.minDeg ? Int((Tuning.lifeThreshold / slope).rounded()) : nil
//    }
//
//    var lifeText: String {
//        guard hasDeg else { return "Not enough long runs" }
//        guard let life = tyreLife else { return "No measurable wear" }
//        if life > maxAge + 3 { return "Beyond data (>\(maxAge) laps)" }
//        return "~\(life) laps"
//    }
//
//    var color: Color {
//        switch name.uppercased() {
//        case "SOFT": return .red
//        case "MEDIUM": return .yellow
//        case "HARD": return .gray
//        case "INTERMEDIATE": return .green
//        case "WET": return .blue
//        default: return .purple
//        }
//    }
//
//    var sortOrder: Int {
//        switch name.uppercased() {
//        case "SOFT": return 0
//        case "MEDIUM": return 1
//        case "HARD": return 2
//        case "INTERMEDIATE": return 3
//        case "WET": return 4
//        default: return 5
//        }
//    }
//}
//
//struct PaceReport {
//    let stats: [CompoundStats]
//    let reference: CompoundStats
//
//    /// Cumulative time difference vs the reference after N laps on one set (no extrapolation past observed age)
//    func crossoverPoints() -> [CrossPoint] {
//        stats.flatMap { s -> [CrossPoint] in
//            (1...max(1, s.maxAge)).map { n in
//                let nd = Double(n)
//                let delta = nd * (s.intercept - reference.intercept)
//                    + (s.slope - reference.slope) * nd * (nd + 1) / 2
//                return CrossPoint(compound: s.name, lap: n, delta: delta)
//            }
//        }
//    }
//}
//
//// MARK: - Crossover Chart
//
//private struct CrossoverCard: View {
//    let report: PaceReport
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text("Cumulative time vs \(report.reference.name.capitalized)")
//                .font(.headline)
//            Text("Below 0 = ahead of the reference after N laps on one set")
//                .font(.caption)
//                .foregroundStyle(.secondary)
//
//            Chart(report.crossoverPoints()) { p in
//                LineMark(
//                    x: .value("Laps", p.lap),
//                    y: .value("Delta", p.delta),
//                    series: .value("Compound", p.compound)
//                )
//                .foregroundStyle(by: .value("Compound", p.compound))
//                .lineStyle(StrokeStyle(lineWidth: 2))
//            }
//            .chartForegroundStyleScale(
//                domain: report.stats.map { $0.name },
//                range: report.stats.map { $0.color }
//            )
//            .chartXAxisLabel("Laps on tyre")
//            .chartYAxis {
//                AxisMarks(position: .leading) { value in
//                    AxisGridLine()
//                    AxisTick()
//                    AxisValueLabel {
//                        if let s = value.as(Double.self) {
//                            Text(String(format: "%+.1fs", s)).font(.caption2.monospacedDigit())
//                        }
//                    }
//                }
//            }
//            .frame(height: 240)
//        }
//        .padding()
//        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
//    }
//}
//
//// MARK: - Per-compound Card
//
//private struct CompoundStatsCard: View {
//    let stats: CompoundStats
//    let reference: CompoundStats
//
//    private var isReference: Bool { stats.name == reference.name }
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            HStack {
//                Circle().fill(stats.color).frame(width: 12, height: 12)
//                Text(stats.name.capitalized).font(.headline)
//                if isReference {
//                    Text("reference").font(.caption).foregroundStyle(.secondary)
//                }
//                Spacer()
//            }
//
//            HStack(alignment: .top) {
//                stat("Pace", isReference ? "—" : String(format: "%+.2fs", stats.intercept - reference.intercept))
//                stat("Deg", String(format: "%.3f s/lap", stats.slope))
//                stat("Usable life", stats.lifeText)
//            }
//
//            Chart {
//                ForEach(stats.points) { p in
//                    PointMark(
//                        x: .value("Tyre Age", p.tyreAge),
//                        y: .value("Delta", p.delta)
//                    )
//                    .foregroundStyle(stats.color.opacity(0.4))
//                    .symbolSize(18)
//                }
//                ForEach([1, stats.maxAge], id: \.self) { age in
//                    LineMark(
//                        x: .value("Tyre Age", age),
//                        y: .value("Fit", stats.intercept + stats.slope * Double(age)),
//                        series: .value("Series", "Fit")
//                    )
//                    .foregroundStyle(.primary)
//                    .lineStyle(StrokeStyle(lineWidth: 2))
//                }
//            }
//            .chartXAxisLabel("Tyre age (laps)")
//            .chartYAxis {
//                AxisMarks(position: .leading) { value in
//                    AxisGridLine()
//                    AxisTick()
//                    AxisValueLabel {
//                        if let s = value.as(Double.self) {
//                            Text(String(format: "%+.1fs", s)).font(.caption2.monospacedDigit())
//                        }
//                    }
//                }
//            }
//            .frame(height: 180)
//
//            Text("\(stats.points.count) laps · \(stats.driverCount) drivers · up to age \(stats.maxAge)")
//                .font(.caption)
//                .foregroundStyle(.secondary)
//        }
//        .padding()
//        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
//    }
//
//    private func stat(_ label: String, _ value: String) -> some View {
//        VStack(alignment: .leading, spacing: 2) {
//            Text(label).font(.caption).foregroundStyle(.secondary)
//            Text(value).font(.subheadline.monospacedDigit())
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//    }
//}
