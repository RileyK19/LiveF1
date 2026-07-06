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
    let driverNumber: Int
    let lap: F1Lap

    init(session: F1PredictorSession, driverNumber: Int, lap: F1Lap) {
        _viewModel = StateObject(wrappedValue: SpeedTraceViewModel(session: session))
        self.driverNumber = driverNumber
        self.lap = lap
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
                            LineMark(x: .value("Time", $0.date), y: .value("Speed", $0.speed ?? 0))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(.red)
                        }
                        .frame(height: 160)

                        Text("Throttle").font(.caption).foregroundStyle(.secondary)
                        Chart(viewModel.samples) {
                            LineMark(x: .value("Time", $0.date), y: .value("Throttle", $0.throttle ?? 0))
                                .foregroundStyle(.green)
                        }
                        .frame(height: 90)

                        Text("Brake").font(.caption).foregroundStyle(.secondary)
                        Chart(viewModel.samples) {
                            AreaMark(x: .value("Time", $0.date), y: .value("Brake", $0.brake ?? 0))
                                .foregroundStyle(.orange.opacity(0.6))
                        }
                        .frame(height: 60)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Lap \(lap.lapNumber) · #\(driverNumber)")
        .task { await viewModel.loadLap(lap, driverNumber: driverNumber) }
    }
}
