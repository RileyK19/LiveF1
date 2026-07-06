//
//  RacePaceView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/5/26.
//

import SwiftUI
import Charts

struct RacePaceView: View {
    @StateObject private var viewModel: RacePaceViewModel
    let existingLaps: [F1Lap]?

    private let widthPerDriver: CGFloat = 70
    
    private var yDomain: ClosedRange<Double> {
        let allValues = viewModel.driverStats.flatMap { [$0.min, $0.max] }
        guard let lo = allValues.min(), let hi = allValues.max() else { return 95...105 }
        let padding = (hi - lo) * 0.1
        return (lo - padding)...(hi + padding)
    }

    init(session: F1PredictorSession, existingLaps: [F1Lap]? = nil) {
        _viewModel = StateObject(wrappedValue: RacePaceViewModel(session: session))
        self.existingLaps = existingLaps
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Crunching lap times...")
            } else if let error = viewModel.error {
                Text(error).foregroundStyle(.red)
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    Chart(viewModel.driverStats) { stat in
                        RuleMark(
                            x: .value("Driver", "#\(stat.driverNumber)"),
                            yStart: .value("Min", stat.min),
                            yEnd: .value("Max", stat.max)
                        )
                        .foregroundStyle(.secondary)

                        RectangleMark(
                            x: .value("Driver", "#\(stat.driverNumber)"),
                            yStart: .value("Q1", stat.q1),
                            yEnd: .value("Q3", stat.q3),
                            width: .fixed(28)
                        )
                        .foregroundStyle(.blue.opacity(0.7))
                        .cornerRadius(2)

                        PointMark(
                            x: .value("Driver", "#\(stat.driverNumber)"),
                            y: .value("Median", stat.median)
                        )
                        .symbol {
                            Rectangle()
                                .frame(width: 26, height: 2)
                                .foregroundStyle(.primary)
                        }
                    }
                    .chartYScale(domain: yDomain)
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let percent = value.as(Double.self) {
                                    Text("\(percent, specifier: "%.0f")%")
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { AxisValueLabel().font(.caption) }
                    }
                    .frame(width: CGFloat(viewModel.driverStats.count) * widthPerDriver, height: 320)
                    .padding()
                }
            }
        }
        .navigationTitle("Race Pace")
        .task { await viewModel.load(existingLaps: existingLaps) }
    }
}
