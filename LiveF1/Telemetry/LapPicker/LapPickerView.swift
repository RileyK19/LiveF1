//
//  LapPickerView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/5/26.
//

import SwiftUI
import Combine

enum LapPickerDestination {
    case speedTrace
    case lapReplay

    var icon: String {
        switch self {
        case .speedTrace: return "chart.line.uptrend.xyaxis"
        case .lapReplay:  return "play.circle"
        }
    }

    func label(count: Int) -> String {
        switch self {
        case .speedTrace:
            return "Compare \(count) Lap\(count == 1 ? "" : "s")"
        case .lapReplay:
            return count == 1 ? "Watch Replay" : "Replay \(count) Laps"
        }
    }
}

struct LapPickerView: View {
    @StateObject private var viewModel: LapPickerViewModel
    let session: F1PredictorSession
    let destination: LapPickerDestination

    init(session: F1PredictorSession, destination: LapPickerDestination, allowsMultipleSelection: Bool = true) {
        self.session = session
        self.destination = destination
        _viewModel = StateObject(wrappedValue: LapPickerViewModel(
            session: session, allowsMultipleSelection: allowsMultipleSelection
        ))
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
                ZStack {
                    VStack(spacing: 0) {

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.drivers, id: \.self) { driver in
                                    Button {
                                        viewModel.selectedDriverNumber = driver
                                    } label: {
                                        Text("#\(driver)").tag(Optional(driver))
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(viewModel.selectedDriverNumber == driver ? Color.accentColor : Color(.secondarySystemBackground))
                                            .foregroundStyle(viewModel.selectedDriverNumber == driver ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding()

                        List(viewModel.lapsForSelectedDriver) { lap in
                            Button {
                                viewModel.toggleSelection(lap)
                            } label: {
                                HStack {
                                    Text("Lap \(lap.lapNumber)")
                                        .foregroundStyle(lapColor(lap: lap))
                                    Spacer()
                                    Text(lap.formattedLapTime).foregroundStyle(.secondary)
                                    Image(systemName: viewModel.isSelected(lap) ? "checkmark.circle.fill" : "circle")
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .listStyle(.insetGrouped)
                    }
                    if !viewModel.selectedLaps.isEmpty {
                        VStack {
                            Spacer()
                            NavigationLink(value: destinationValue) {
                                HStack {
                                    Image(systemName: destination.icon)
                                    Text(destination.label(count: viewModel.selectedLaps.count))
                                        .fontWeight(.semibold)
                                        .padding(5)
                                }
                                .padding(14)
                            }
                            .buttonStyle(.glassProminent)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Lap")
        .task { await viewModel.load() }
    }

    private var destinationValue: Destination {
        switch destination {
        case .speedTrace:
            return .speedTrace(session, viewModel.selectedLaps)
        case .lapReplay:
            return .lapReplay(session, viewModel.selectedLaps)
        }
    }

    private func lapColor(lap: F1Lap) -> Color {
        guard let minLap = viewModel.lapsForSelectedDriver
            .filter({ $0.lapDuration != nil })
            .min(by: { $0.lapDuration! < $1.lapDuration! }),
              let lapDuration = lap.lapDuration,
              let minLapDuration = minLap.lapDuration,
              let fastest = viewModel.laps.compactMap(\.lapDuration).min()
        else {
            return .primary
        }
        if fastest == lapDuration {
            return .purple
        }
        if minLap.id == lap.id {
            return .green
        }
        if minLapDuration * 1.10 < lapDuration {
            return .red
        }
        return .primary
    }
}
