//
//  RacePaceView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/5/26.
//

import SwiftUI
import Charts

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

    @State private var showFilterSheet = false
    @State private var selectedDriverNumbers: Set<Int> = []   // empty = show all
    @State private var selectedStat: DriverPaceStats?          // CHANGED: drives inline overlay, not sheet
    @State private var tapPosition: CGPoint = .zero            // where to anchor the overlay

    private var filteredStats: [DriverPaceStats] {
        selectedDriverNumbers.isEmpty
            ? viewModel.driverStats
            : viewModel.driverStats.filter { selectedDriverNumbers.contains($0.driverNumber) }
    }

    private var yDomain: ClosedRange<Double> {
        let allValues = filteredStats.flatMap { [$0.min, $0.max] }
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
                GeometryReader { geo in
                    let fitCount = max(1, Int(geo.size.width / widthPerDriver))
                    let visibleCount = min(filteredStats.count, fitCount)

                    ZStack(alignment: .topLeading) {
                        Chart(filteredStats) { stat in
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
                                        let seconds = viewModel.fastestLapTime * (percent / 100)
                                        VStack(alignment: .trailing, spacing: 1) {
                                            Text("\(Int(percent))%")
                                            Text(formatLapTime(seconds))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks { AxisValueLabel().font(.caption) }
                        }
                        .chartScrollableAxes(filteredStats.count > fitCount ? .horizontal : [])
                        .chartXVisibleDomain(length: visibleCount)
                        .chartOverlay { proxy in
                            GeometryReader { chartGeo in
                                ZStack(alignment: .topLeading) {
                                    ForEach(filteredStats) { stat in
                                        if let xPos = proxy.position(forX: "#\(stat.driverNumber)") {
                                            Button {
                                                if selectedStat?.id == stat.id {
                                                    selectedStat = nil
                                                } else {
                                                    selectedStat = stat
                                                    let origin = chartGeo[proxy.plotAreaFrame].origin
                                                    tapPosition = CGPoint(x: origin.x + xPos, y: origin.y + 40)
                                                }
                                            } label: {
                                                Color.clear
                                            }
                                            .frame(width: widthPerDriver * 0.6, height: chartGeo[proxy.plotAreaFrame].height)
                                            .position(x: chartGeo[proxy.plotAreaFrame].origin.x + xPos,
                                                      y: chartGeo[proxy.plotAreaFrame].origin.y + chartGeo[proxy.plotAreaFrame].height / 2)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()

                        // NEW: floating overlay card
                        if let stat = selectedStat {
                            DriverStatOverlayCard(stat: stat, fastestLapTime: viewModel.fastestLapTime) {
                                selectedStat = nil
                            }
                            .position(
                                x: min(max(tapPosition.x, 90), geo.size.width - 90),
                                y: max(tapPosition.y - 70, 60)
                            )
                        }
                    }
                }
                .frame(height: 320 + 40)
            }
        }
        .navigationTitle("Race Pace")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            RacePaceFilterSheet(
                allDriverNumbers: viewModel.driverStats.map(\.driverNumber).sorted(),
                selectedDriverNumbers: $selectedDriverNumbers
            )
        }
        .task { await viewModel.load(existingLaps: existingLaps) }
    }
}
private func formatLapTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "--:--.---" }
    let minutes = Int(seconds) / 60
    let secs = seconds.truncatingRemainder(dividingBy: 60)
    return String(format: "%d:%06.3f", minutes, secs)
}

struct RacePaceFilterSheet: View {
    let allDriverNumbers: [Int]
    @Binding var selectedDriverNumbers: Set<Int>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
//        NavigationStack {
            List(allDriverNumbers, id: \.self) { number in
                Button {
                    if selectedDriverNumbers.contains(number) {
                        selectedDriverNumbers.remove(number)
                    } else {
                        selectedDriverNumbers.insert(number)
                    }
                } label: {
                    HStack {
                        Text("#\(number)")
                        Spacer()
                        if selectedDriverNumbers.contains(number) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
            .navigationTitle("Filter Drivers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") { selectedDriverNumbers.removeAll() }
                }
            }
//        }
    }
}

struct DriverStatOverlayCard: View {
    let stat: DriverPaceStats
    let fastestLapTime: Double
    let onDismiss: () -> Void

    private func time(forPercent percent: Double) -> String {
        formatLapTime(fastestLapTime * (percent / 100))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("#\(stat.driverNumber)").font(.headline)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            row("Max", stat.max)
            row("Q3", stat.q3)
            row("Median", stat.median)
            row("Q1", stat.q1)
            row("Min", stat.min)
        }
        .font(.caption)
        .padding(10)
        .frame(width: 180)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 4)
    }

    @ViewBuilder
    private func row(_ label: String, _ percent: Double) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text("\(String(format: "%.1f", percent))% (\(time(forPercent: percent)))")
        }
    }
}
