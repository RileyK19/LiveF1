//
//  SessionPickerView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//

import SwiftUI

struct SessionPickerView<Destination: View>: View {
    @StateObject private var viewModel = SessionPickerViewModel()

    let title: String
    let destination: (F1PredictorSession) -> Destination

    init(
        title: String = "2026 Season",
        sessionType: String? = "Race",
        @ViewBuilder destination: @escaping (F1PredictorSession) -> Destination
    ) {
        self.title = title
        self.destination = destination
        _viewModel = StateObject(wrappedValue: SessionPickerViewModel(sessionType: sessionType))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading races...")
                } else if let error = viewModel.error {
                    VStack(spacing: 12) {
                        Text("Failed to load sessions")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Note: Data not available during live sessions due to OpenF1 restrictions")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await viewModel.load() }
                        }
                    }
                } else {
                    List(viewModel.sessions) { session in
                        NavigationLink(destination: destination(session)) {
                            SessionRowView(session: session)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(title)
            .task { await viewModel.load() }
        }
    }
}

struct SessionRowView: View {
    let session: F1PredictorSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.countryName)
                    .font(.headline)
                Spacer()
                Text(session.sessionName)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(sessionColor.opacity(0.15))
                    .foregroundStyle(sessionColor)
                    .clipShape(Capsule())
            }
            Text(session.circuitShortName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let date = session.dateStart {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var sessionColor: Color {
        switch session.sessionName {
        case "Race": return .red
        case "Qualifying": return .blue
        case "Sprint": return .orange
        case "Sprint Qualifying", "Sprint Shootout": return .purple
        default: return .secondary // Practice 1/2/3, etc.
        }
    }
}
