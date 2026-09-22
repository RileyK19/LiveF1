//
//  LapReplayView.swift
//  Redline
//
//  Created by Riley Koo on 8/27/26.
//

import SwiftUI
import Charts

struct LapReplayView: View {
    @StateObject private var viewModel: LapReplayViewModel
    let laps: [F1Lap]

    /// Whether the map is zoomed/following the current car(s) rather than showing the whole track.
    @State private var isZoomed = false

    init(session: F1PredictorSession, laps: [F1Lap]) {
        _viewModel = StateObject(wrappedValue: LapReplayViewModel(session: session))
        self.laps = laps
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading position data...")
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Lap line is fitted onto OpenStreetMap roads and may not align perfectly")
                            .font(.caption2)
                            .fontWeight(.light)
                            .foregroundStyle(.secondary)
                        if let error = viewModel.error {
                            Text(error).font(.caption2).foregroundStyle(.orange)
                        }
                        trackMap
                        controls
                        telemetryReadout
                        telemetryTraces
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(laps.count == 1 ? "Lap \(laps[0].lapNumber) · #\(laps[0].driverNumber) · \(viewModel.session.location)" : "\(laps.count) Laps")
        .task {
            await viewModel.loadLaps(laps)
        }
        .onDisappear {
            viewModel.pause()
        }
    }

    // MARK: - Apple Maps overlay

    private var trackMap: some View {
        LapReplayMapView(viewModel: viewModel, isZoomed: isZoomed)
            .frame(height: 340)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                zoomToggle
            }
    }

    private var zoomToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isZoomed.toggle()
            }
        } label: {
            Image(systemName: isZoomed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.caption)
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())
        }
        .padding(8)
        .accessibilityLabel(isZoomed ? "Show full track" : "Zoom to car")
    }

    // MARK: - Telemetry readout, synced to scrub position

    private var telemetryReadout: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.liveReadouts()) { readout in
                HStack(spacing: 12) {
                    Circle().fill(readout.color).frame(width: 10, height: 10)
                    Text(readout.id).font(.caption).bold().frame(width: 70, alignment: .leading)
                    readoutLabel("SPD", readout.speed.map { "\($0)" } ?? "–")
                    readoutLabel("THR", readout.throttle.map { "\($0)%" } ?? "–")
                    readoutLabel("BRK", readout.brake.map { $0 > 0 ? "ON" : "off" } ?? "–")
                    readoutLabel("GEAR", readout.gear.map { "\($0)" } ?? "–")
                }
                .font(.caption.monospacedDigit())
            }
        }
    }

    private func readoutLabel(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value)
        }
        .frame(width: 50, alignment: .leading)
    }

    // MARK: - Playback controls

    private var controls: some View {
        HStack(spacing: 20) {
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 32)
            }

            Button {
                viewModel.restart()
            } label: {
                Image(systemName: "gobackward")
                    .font(.title2)
                    .frame(width: 32)
            }

            Text(String(format: "%.1fs / %.1fs", viewModel.currentTime, viewModel.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Throttle / brake / gear traces with a moving playhead

    private var telemetryTraces: some View {
        VStack(alignment: .leading, spacing: 14) {
            trace(title: "Throttle", range: 0...100) { $0.throttle }
            trace(title: "Brake", range: 0...100) { $0.brake }
            gearTrace
        }
    }

    private func trace(
        title: String, range: ClosedRange<Int>,
        value: @escaping (LapReplayViewModel.ChartSample) -> Int?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Chart(viewModel.chartSamples) { sample in
                if let v = value(sample) {
                    LineMark(x: .value("Elapsed", sample.elapsed), y: .value(title, v))
                        .foregroundStyle(by: .value("Lap", sample.label))
                }
            }
            .chartYScale(domain: range)
            .chartXScale(domain: 0...max(viewModel.duration, 0.01))
            .chartForegroundStyleScale(
                domain: viewModel.traces.map(\.id),
                range: viewModel.traces.map(\.color)
            )
            .chartLegend(.hidden)
            .chartOverlay { proxy in playhead(proxy) }
            .frame(height: 60)
        }
    }

    private var gearTrace: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Gear").font(.caption2).foregroundStyle(.secondary)
            Chart(viewModel.chartSamples) { sample in
                if let gear = sample.gear {
                    LineMark(x: .value("Elapsed", sample.elapsed), y: .value("Gear", gear))
                        .foregroundStyle(by: .value("Lap", sample.label))
                        .interpolationMethod(.stepEnd)
                }
            }
            .chartYScale(domain: 0...9)
            .chartXScale(domain: 0...max(viewModel.duration, 0.01))
            .chartForegroundStyleScale(
                domain: viewModel.traces.map(\.id),
                range: viewModel.traces.map(\.color)
            )
            .chartLegend(.hidden)
            .chartOverlay { proxy in playhead(proxy) }
            .frame(height: 60)
        }
    }

    /// A vertical rule tracking `currentTime`, so the traces scrub in lockstep with the map dot.
    @ViewBuilder
    private func playhead(_ proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            if let x = proxy.position(forX: viewModel.currentTime) {
                let plotArea = geo[proxy.plotAreaFrame]
                Path { path in
                    path.move(to: CGPoint(x: plotArea.minX + x, y: plotArea.minY))
                    path.addLine(to: CGPoint(x: plotArea.minX + x, y: plotArea.maxY))
                }
                .stroke(Color.primary.opacity(0.5), lineWidth: 1)
            }
        }
    }
}
