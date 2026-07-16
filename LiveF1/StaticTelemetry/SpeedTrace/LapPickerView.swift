//
//  LapPickerView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/5/26.
//

import SwiftUI
import Combine

struct LapPickerView: View {
    @StateObject private var viewModel: LapPickerViewModel
    let session: F1PredictorSession

    init(session: F1PredictorSession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: LapPickerViewModel(session: session))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading laps...")
            } else if let error = viewModel.error {
                VStack(spacing: 12) {
                    Text("Failed to load laps").font(.headline)
                    Text(error).font(.caption).foregroundStyle(.secondary)
                    Button("Retry") { Task { await viewModel.load() } }
                }
            } else {
                VStack(spacing: 0) {
                    Picker("Driver", selection: $viewModel.selectedDriverNumber) {
                        ForEach(viewModel.drivers, id: \.self) { driver in
                            Text("#\(driver)").tag(Optional(driver))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()

                    List(viewModel.lapsForSelectedDriver) { lap in
                        Button {
                            viewModel.toggleSelection(lap)
                        } label: {
                            HStack {
                                Text("Lap \(lap.lapNumber)")
                                Spacer()
                                Text(lap.formattedLapTime).foregroundStyle(.secondary)
                                Image(systemName: viewModel.isSelected(lap) ? "checkmark.circle.fill" : "circle")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)

                    if !viewModel.selectedLaps.isEmpty {
                        NavigationLink("Compare \(viewModel.selectedLaps.count) Laps") {
                            SpeedTraceView(session: session, laps: viewModel.selectedLaps)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Select Lap")
        .task { await viewModel.load() }
    }
}
