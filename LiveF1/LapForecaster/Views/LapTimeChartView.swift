//
//  LapTimeChartView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//

import SwiftUI
import Charts

enum ChartPage: Int, CaseIterable {
    case raw
    case adjusted

    var title: String {
        switch self {
        case .raw:      return "Lap Times"
        case .adjusted: return "True Degradation"
        }
    }

    var subtitle: String {
        switch self {
        case .raw:      return "Absolute lap times with regression"
        case .adjusted: return "Track evolution removed"
        }
    }
}

struct LapTimeChartView: View {
    @ObservedObject var viewModel: RaceViewModel
    @State private var currentPage: ChartPage = .raw

    var body: some View {
        if viewModel.annotatedLaps.isEmpty {
            ContentUnavailableView("No lap data", systemImage: "flag.checkered")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Page indicator
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentPage.title)
                            .font(.title2.bold())
                        Text(currentPage.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Swipeable chart
                    TabView(selection: $currentPage) {
                        rawChartPage
                            .tag(ChartPage.raw)
                        adjustedChartPage
                            .tag(ChartPage.adjusted)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 340)

                    compoundLegend
                        .padding(.horizontal)

                    stintSummary
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
    }

    // MARK: - Raw page

    private var rawChartPage: some View {
        Chart {
            ForEach(viewModel.annotatedLaps) { annotated in
                LineMark(
                    x: .value("Lap", annotated.lap.lapNumber),
                    y: .value("Time", annotated.lapDuration),
                    series: .value("Series", "actual")
                )
                .foregroundStyle(Color(hex: annotated.compound.color))

                PointMark(
                    x: .value("Lap", annotated.lap.lapNumber),
                    y: .value("Time", annotated.lapDuration)
                )
                .foregroundStyle(Color(hex: annotated.compound.color))
            }
            rawRegressionLines
        }
        .chartYScale(domain: rawLapTimeRange)
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text(formatLapTime(seconds))
                            .font(.caption)
                    }
                }
                AxisGridLine()
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) {
                AxisValueLabel()
                AxisGridLine()
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Adjusted page

    private var adjustedChartPage: some View {
        Chart {
            // Zero reference line (flat track evolution)
            RuleMark(y: .value("Field Pace", 0))
                .foregroundStyle(.white.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .trailing) {
                    Text("Field")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

            ForEach(viewModel.adjustedAnnotatedLaps) { annotated in
                PointMark(
                    x: .value("Lap", annotated.lap.lapNumber),
                    y: .value("Delta", annotated.lapDuration)
                )
                .foregroundStyle(Color(hex: annotated.compound.color))
            }
            adjustedRegressionLines
        }
        .chartYScale(domain: adjustedLapTimeRange)
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text(formatDelta(seconds))
                            .font(.caption)
                    }
                }
                AxisGridLine()
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) {
                AxisValueLabel()
                AxisGridLine()
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Regression lines

    @ChartContentBuilder
    private var rawRegressionLines: some ChartContent {
        ForEach(viewModel.stintRegressionLines, id: \.stint.id) { entry in
            let minAge = entry.laps.map { $0.tyreAge }.min() ?? 0
            let maxAge = entry.laps.map { $0.tyreAge }.max() ?? 0
            let minLap = entry.laps.map { $0.lap.lapNumber }.min() ?? 0
            let points: [(lap: Int, time: Double)] = (minAge...maxAge).map { age in
                (lap: minLap + (age - minAge),
                 time: entry.model.predictedLapTime(atTyreAge: age))
            }
            ForEach(points, id: \.lap) { point in
                LineMark(
                    x: .value("Lap", point.lap),
                    y: .value("Time", point.time),
                    series: .value("Reg", "reg-\(entry.stint.id)")
                )
                .foregroundStyle(Color(hex: entry.stint.compoundEnum.darkColor).opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 3, dash: [5, 3]))
            }
        }
    }

    @ChartContentBuilder
    private var adjustedRegressionLines: some ChartContent {
        ForEach(viewModel.adjustedStintRegressionLines, id: \.stint.id) { entry in
            let minAge = entry.laps.map { $0.tyreAge }.min() ?? 0
            let maxAge = entry.laps.map { $0.tyreAge }.max() ?? 0
            let minLap = entry.laps.map { $0.lap.lapNumber }.min() ?? 0
            let points: [(lap: Int, time: Double)] = (minAge...maxAge).map { age in
                (lap: minLap + (age - minAge),
                 time: entry.model.predictedLapTime(atTyreAge: age))
            }
            ForEach(points, id: \.lap) { point in
                LineMark(
                    x: .value("Lap", point.lap),
                    y: .value("Delta", point.time),
                    series: .value("Reg", "adj-reg-\(entry.stint.id)")
                )
                .foregroundStyle(Color(hex: entry.stint.compoundEnum.darkColor).opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 3, dash: [5, 3]))
            }
        }
    }

    // MARK: - Y axis ranges

    private var rawLapTimeRange: ClosedRange<Double> {
        let durations = viewModel.annotatedLaps.map { $0.lapDuration }
        guard !durations.isEmpty else { return 60...120 }
        let sorted = durations.sorted()
        let trimIndex = max(0, Int(Double(sorted.count) * 0.85))
        let trimmed = Array(sorted.prefix(trimIndex + 1))
        let min = (trimmed.min() ?? 60) - 0.5
        let max = (trimmed.max() ?? 120) + 0.5
        return min...max
    }

    private var adjustedLapTimeRange: ClosedRange<Double> {
        let deltas = viewModel.adjustedAnnotatedLaps.map { $0.lapDuration }
        guard !deltas.isEmpty else { return -5...5 }
        let sorted = deltas.sorted()
        let trimIndex = max(0, Int(Double(sorted.count) * 0.85))
        let trimmed = Array(sorted.prefix(trimIndex + 1))
        let min = (trimmed.min() ?? -5) - 0.5
        let max = (trimmed.max() ?? 5) + 0.5
        return min...max
    }

    // MARK: - Supporting views

    private var compoundLegend: some View {
        HStack(spacing: 16) {
            ForEach(usedCompounds, id: \.rawValue) { compound in
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: compound.color))
                        .frame(width: 10, height: 10)
                    Text(compound.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var stintSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stints")
                .font(.headline)
            ForEach(viewModel.stintsForSelectedDriver) { stint in
                HStack {
                    Circle()
                        .fill(Color(hex: stint.compoundEnum.color))
                        .frame(width: 10, height: 10)
                    Text(stint.compoundEnum.rawValue.capitalized)
                        .font(.subheadline)
                    Spacer()
                    Text("Laps \(stint.lapStart)–\(stint.lapEnd ?? 0)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if stint.tyreAgeAtStart > 0 {
                        Text("(+\(stint.tyreAgeAtStart) used)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var usedCompounds: [TyreCompound] {
        Array(Set(viewModel.annotatedLaps.map { $0.compound }))
            .sorted { $0.rawValue < $1.rawValue }
    }

    private func formatLapTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", m, s)
    }

    private func formatDelta(_ seconds: Double) -> String {
        let sign = seconds >= 0 ? "+" : ""
        return String(format: "\(sign)%.2fs", seconds)
    }
}
