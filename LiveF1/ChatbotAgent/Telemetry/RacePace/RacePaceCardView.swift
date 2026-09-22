//
//  RacePaceCardView.swift
//  Redline
//
//  Created by Riley Koo on 9/17/26.
//

import SwiftUI
import Charts

struct RacePaceCardView: View {
    let focusedStats: [DriverPaceStats]
    let allStats: [DriverPaceStats]
    let result: GetRacePaceResult

    @State private var showAll = false

    private let rowHeight: CGFloat = 28
    private let maxVisibleRows = 8

    private var isFiltered: Bool {
        focusedStats.count != allStats.count
    }

    private var displayed: [DriverPaceStats] {
        showAll ? allStats : focusedStats
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !result.success {
                Text(result.errorMessage ?? "Couldn't compute race pace.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                header
                boxPlot
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack {
            Text("Race Pace")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let lapsConsidered = result.lapsConsidered {
                Text("· \(lapsConsidered)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isFiltered {
                Button {
                    showAll.toggle()
                } label: {
                    Text(showAll ? "Show selected" : "Show all drivers")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
    }

    private var boxPlot: some View {
        let totalHeight = CGFloat(displayed.count) * rowHeight
        let visibleHeight = min(totalHeight, CGFloat(maxVisibleRows) * rowHeight)
        let domain = xDomain

        return Chart(displayed) { stat in
            RuleMark(
                xStart: .value("Min", stat.min),
                xEnd: .value("Max", stat.max),
                y: .value("Driver", label(for: stat))
            )
            .foregroundStyle(.secondary)
            .lineStyle(StrokeStyle(lineWidth: 1))

            RectangleMark(
                xStart: .value("Q1", stat.q1),
                xEnd: .value("Q3", stat.q3),
                y: .value("Driver", label(for: stat)),
                height: .fixed(14)
            )
            .foregroundStyle(isFastest(stat) ? Color.yellow : Color.red.opacity(0.7))
            .cornerRadius(2)

            PointMark(
                x: .value("Median", stat.median),
                y: .value("Driver", label(for: stat))
            )
            .symbol {
                Rectangle()
                    .frame(width: 2, height: 14)
                    .foregroundStyle(.primary)
            }
        }
        .chartXScale(domain: domain)
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let percent = value.as(Double.self) {
                        Text("\(Int(percent))%")
                    }
                }
                .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks { AxisValueLabel().font(.caption2) }
        }
        .chartScrollableAxes(displayed.count > maxVisibleRows ? .vertical : [])
        .chartYVisibleDomain(length: min(displayed.count, maxVisibleRows))
        .frame(height: visibleHeight)
    }

    private var xDomain: ClosedRange<Double> {
        let values = displayed.flatMap { [$0.min, $0.max] }
        guard let lo = values.min(), let hi = values.max(), hi > lo else { return 95...105 }
        let padding = (hi - lo) * 0.1
        return (lo - padding)...(hi + padding)
    }

    private func label(for stat: DriverPaceStats) -> String {
        "#\(stat.driverNumber)"
    }

    private func isFastest(_ stat: DriverPaceStats) -> Bool {
        result.summaries.first { $0.driverNumber == stat.driverNumber }?.isFastest ?? false
    }
}
