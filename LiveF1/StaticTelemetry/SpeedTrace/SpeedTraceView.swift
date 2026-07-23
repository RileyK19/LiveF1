//
//  SpeedTraceView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/5/26.
//

import SwiftUI
import Charts

struct SpeedTraceView: View {
    @StateObject private var viewModel: SpeedTraceViewModel
    let laps: [F1Lap]
    @State private var zoom: Double = 30   // seconds visible
    @State private var scrollPosition: Double = 0

    init(session: F1PredictorSession, laps: [F1Lap]) {
        _viewModel = StateObject(wrappedValue: SpeedTraceViewModel(session: session))
        self.laps = laps
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading telemetry...")
            } else if let error = viewModel.error {
                Text(error).foregroundStyle(.red)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Speed").font(.caption).foregroundStyle(.secondary)
                        Chart(viewModel.samples) {
                            LineMark(x: .value("Elapsed", $0.elapsed), y: .value("Speed", $0.speed ?? 0))
                                .foregroundStyle(by: .value("Lap", $0.label))
                                .interpolationMethod(.catmullRom)
                        }
                        .frame(height: 160)
                        .chartScrollableAxes(.horizontal)
                        .chartXVisibleDomain(length: zoom)
                        .chartScrollPosition(x: $scrollPosition)

                        Text("Throttle").font(.caption).foregroundStyle(.secondary)
                        Chart(viewModel.samples) {
                            LineMark(x: .value("Elapsed", $0.elapsed), y: .value("Throttle", $0.throttle ?? 0))
                                .foregroundStyle(by: .value("Lap", $0.label))
                        }
                        .frame(height: 90)
                        .chartScrollableAxes(.horizontal)
                        .chartXVisibleDomain(length: zoom)
                        .chartScrollPosition(x: $scrollPosition)

                        Text("Brake").font(.caption).foregroundStyle(.secondary)
                        Chart(viewModel.samples) {
                            LineMark(x: .value("Elapsed", $0.elapsed), y: .value("Brake", $0.brake ?? 0))
                                .foregroundStyle(by: .value("Lap", $0.label))
                        }
                        .frame(height: 60)
                        .chartScrollableAxes(.horizontal)
                        .chartXVisibleDomain(length: zoom)
                        .chartScrollPosition(x: $scrollPosition)
                        
                        Text("Gear").font(.caption).foregroundStyle(.secondary)
                        Chart(viewModel.samples) {
                            LineMark(x: .value("Elapsed", $0.elapsed), y: .value("Gear", $0.gear ?? 0))
                                .foregroundStyle(by: .value("Lap", $0.label))
                        }
                        .frame(height: 90)
                        .chartScrollableAxes(.horizontal)
                        .chartXVisibleDomain(length: zoom)
                        .chartScrollPosition(x: $scrollPosition)

                        // Simplest possible zoom control: a slider
                        Slider(value: $zoom, in: 1...(viewModel.samples.map(\.elapsed).max() ?? 60))
                        Text("Zoom: \(Int(zoom))s window").font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(laps.count == 1 ? "Lap \(laps[0].lapNumber) · #\(laps[0].driverNumber)" : "\(laps.count) Laps")
        .task {
            await viewModel.loadLaps(laps)
            zoom = viewModel.samples.map(\.elapsed).max() ?? 30
        }
    }
}
