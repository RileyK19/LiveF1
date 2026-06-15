//
//  SessionPickerView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//

import SwiftUI

struct SessionPickerView: View {
    @StateObject private var viewModel = SessionPickerViewModel()

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
                        Button("Retry") {
                            Task { await viewModel.load() }
                        }
                    }
                } else {
                    List(viewModel.sessions) { session in
                        NavigationLink(destination: RaceDetailView(session: session)) {
                            SessionRowView(session: session)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("2026 Season")
            .task { await viewModel.load() }
        }
    }
}

struct SessionRowView: View {
    let session: F1PredictorSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.countryName)
                .font(.headline)
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
}
