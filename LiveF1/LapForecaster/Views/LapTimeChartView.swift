//
//  LapTimeChartView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//

import SwiftUI
import Charts

struct LapTimeChartView: View {
    @ObservedObject var viewModel: RaceViewModel
    
    private var lapTimeRange: ClosedRange<Double> {
        let durations = viewModel.annotatedLaps.map { $0.lapDuration }
        guard !durations.isEmpty else { return 60...120 }
        let sorted = durations.sorted()
        let trimIndex = max(0, Int(Double(sorted.count) * 0.8))
        let trimmed = Array(sorted.prefix(trimIndex + 1))
        let min = (trimmed.min() ?? 60) - 0.5
        let max = (trimmed.max() ?? 120) + 0.5
        return min...max
    }

    var body: some View {
        if viewModel.annotatedLaps.isEmpty {
            ContentUnavailableView("No lap data", systemImage: "flag.checkered")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Lap Times")
                        .font(.title2.bold())
                        .padding(.horizontal)

                    Chart(viewModel.annotatedLaps) { annotated in
                        LineMark(
                            x: .value("Lap", annotated.lap.lapNumber),
                            y: .value("Time", annotated.lapDuration)
                        )
                        .foregroundStyle(Color(hex: annotated.compound.color))

                        PointMark(
                            x: .value("Lap", annotated.lap.lapNumber),
                            y: .value("Time", annotated.lapDuration)
                        )
                        .foregroundStyle(Color(hex: annotated.compound.color))
                    }
                    .chartYScale(domain: lapTimeRange)
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
                    .frame(height: 300)
                    .padding(.horizontal)

                    compoundLegend
                        .padding(.horizontal)

                    stintSummary
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
    }

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

    private var usedCompounds: [TyreCompound] {
        Array(Set(viewModel.annotatedLaps.map { $0.compound }))
            .sorted { $0.rawValue < $1.rawValue }
    }

    private func formatLapTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", m, s)
    }
}
