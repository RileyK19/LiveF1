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

    @State private var showFilterSheet = false
    @State private var selectedDriverNumbers: Set<Int> = []   // empty = show all

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
                VStack {
                    RacePaceBarChart(viewModel: viewModel, selectedDriverNumbers: $selectedDriverNumbers)
                    
                    RacePaceTimelineChart(
                        paceByLap: viewModel.racePaceByLap,
                        selectedDriverNumbers: selectedDriverNumbers
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showFilterSheet = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        ExportMenu(source: self)
                    }
                }
            }
        }
        .navigationTitle("Race Pace")
        
        .sheet(isPresented: $showFilterSheet) {
            RacePaceFilterSheet(
                allDriverNumbers: viewModel.driverStats.map(\.driverNumber).sorted(),
                selectedDriverNumbers: $selectedDriverNumbers
            )
        }
        .task { await viewModel.load(existingLaps: existingLaps) }
    }
}



extension RacePaceView: Exportable {
    var exportContent: some View {
        RacePaceExportLayout(
            driverStats: viewModel.driverStats,
            paceByLap: viewModel.racePaceByLap,
            selectedDriverNumbers: selectedDriverNumbers,
            fastestLapTime: viewModel.fastestLapTime,
            sessionName: "\(viewModel.session.circuitShortName) Grand Prix"
        )
    }
    var exportFilename: String { "RacePace-\(viewModel.session.circuitShortName)" }
}

struct RacePaceBarChart: View {
    let driverStats: [DriverPaceStats]
    let fastestLapTime: Double

    private let widthPerDriver: CGFloat = 70

    @Binding var selectedDriverNumbers: Set<Int>
    @State private var selectedStat: DriverPaceStats?
    @State private var tapPosition: CGPoint = .zero

    // Plain-data init — used by both live and export paths
    init(
        driverStats: [DriverPaceStats],
        fastestLapTime: Double,
        selectedDriverNumbers: Binding<Set<Int>>
    ) {
        self.driverStats = driverStats
        self.fastestLapTime = fastestLapTime
        self._selectedDriverNumbers = selectedDriverNumbers
    }

    // Convenience init — live screen keeps calling it the same way it does today
    init(viewModel: RacePaceViewModel, selectedDriverNumbers: Binding<Set<Int>>) {
        self.init(
            driverStats: viewModel.driverStats,
            fastestLapTime: viewModel.fastestLapTime,
            selectedDriverNumbers: selectedDriverNumbers
        )
    }

    private var filteredStats: [DriverPaceStats] {
        selectedDriverNumbers.isEmpty
            ? driverStats                                 // was: viewModel.driverStats
            : driverStats.filter { selectedDriverNumbers.contains($0.driverNumber) }
    }

    private var yDomain: ClosedRange<Double> {
        let allValues = filteredStats.flatMap { [$0.min, $0.max] }
        guard let lo = allValues.min(), let hi = allValues.max() else { return 95...105 }
        let padding = (hi - lo) * 0.1
        return (lo - padding)...(hi + padding)
    }

    var body: some View {
        VStack {
            HStack {
                Text("Overall Pace")
                    .font(.headline)
                    .padding()
                
                Spacer()
            }
            
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
                                    let seconds = fastestLapTime * (percent / 100)
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
                                    if let xPos = proxy.position(forX: "#\(stat.driverNumber)"),
                                       let yTop = proxy.position(forY: stat.max),
                                       let yBottom = proxy.position(forY: stat.min) {
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
                                        .frame(width: widthPerDriver * 0.6, height: yBottom - yTop)
                                        .position(
                                            x: chartGeo[proxy.plotAreaFrame].minX + xPos,
                                            y: chartGeo[proxy.plotAreaFrame].minY + (yTop + yBottom) / 2
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    
                    // NEW: floating overlay card
                    if let stat = selectedStat {
                        DriverStatOverlayCard(stat: stat, fastestLapTime: fastestLapTime) {
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

struct RacePaceTimelineChart: View {
    @State private var zoomSpan: Double
    @State private var maxZoomSpan: Double

    let paceByLap: [Int: [DriverPaceStats]]
    let selectedDriverNumbers: Set<Int>
    var showControls: Bool = true

    init(paceByLap: [Int: [DriverPaceStats]], selectedDriverNumbers: Set<Int>, showControls: Bool = true) {
        self.paceByLap = paceByLap
        self.selectedDriverNumbers = selectedDriverNumbers
        self.showControls = showControls

        let fullSpan = Self.computeFullSpan(paceByLap: paceByLap, selectedDriverNumbers: selectedDriverNumbers)
        _zoomSpan = State(initialValue: fullSpan)
        _maxZoomSpan = State(initialValue: fullSpan)
    }

    private var points: [PacePoint] {
        paceByLap
            .sorted { $0.key < $1.key }
            .flatMap { lap, stats in
                stats
                    .filter {
                        selectedDriverNumbers.isEmpty ||
                        selectedDriverNumbers.contains($0.driverNumber)
                    }
                    .map {
                        PacePoint(
                            lap: lap,
                            driverNumber: $0.driverNumber,
                            pace: $0.median
                        )
                    }
            }
    }
    
    private var dataRange: (min: Double, max: Double) {
        let values = points.map(\.pace).filter(\.isFinite)
        guard let minVal = values.min(), let maxVal = values.max() else {
            return (95, 105)
        }
        return (minVal, maxVal)
    }

    private static func computeFullSpan(
        paceByLap: [Int: [DriverPaceStats]],
        selectedDriverNumbers: Set<Int>
    ) -> Double {
        let values = paceByLap
            .flatMap { _, stats in
                stats
                    .filter {
                        selectedDriverNumbers.isEmpty ||
                        selectedDriverNumbers.contains($0.driverNumber)
                    }
                    .map(\.median)
            }
            .filter(\.isFinite) // guard against any NaN/Infinity slipping through

        guard let minVal = values.min(), let maxVal = values.max(), maxVal > minVal else {
            return 10.0
        }

        return max((maxVal - minVal) * 1.2, 0.5)
    }

    private func resetZoomToFit() {
        let fullSpan = Self.computeFullSpan(paceByLap: paceByLap, selectedDriverNumbers: selectedDriverNumbers)
        maxZoomSpan = fullSpan
        zoomSpan = fullSpan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pace over last 5 laps")
                    .font(.headline)

                if showControls {
                    
                    Spacer()
                    
                    Image(systemName: "minus.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Slider(
                        value: $zoomSpan,
                        in: 0.5...maxZoomSpan,
                        step: 0.1
                    )
                    .frame(width: 120)
                    
                    Image(systemName: "plus.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            Chart(points) { point in
                LineMark(
                    x: .value("Lap", point.lap),
                    y: .value("Pace", point.pace)
                )
                .foregroundStyle(by: .value("Driver", "#\(point.driverNumber)"))
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Lap", point.lap),
                    y: .value("Pace", point.pace)
                )
                .foregroundStyle(by: .value("Driver", "#\(point.driverNumber)"))
                .symbolSize(20)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let percent = value.as(Double.self) {
                            Text("\(percent, specifier: "%.1f")%")
                        }
                    }
                }
            }
            .chartLegend(position: .bottom, spacing: 12)
            .chartScrollableAxes(showControls ? [.horizontal, .vertical] : [])
            .chartXVisibleDomain(length: 15)
            .chartYVisibleDomain(length: max(zoomSpan, 0.1))
            .frame(height: 280)
            .padding(.horizontal)
            .onChange(of: dataRange.min) { _, _ in resetZoomToFit() }
            .onChange(of: dataRange.max) { _, _ in resetZoomToFit() }
        }
    }
}

struct PacePoint: Identifiable {
    var id: String { "\(lap)-\(driverNumber)" }
    let lap: Int
    let driverNumber: Int
    let pace: Double
}
