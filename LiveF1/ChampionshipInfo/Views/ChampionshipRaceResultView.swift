//
//  ChampionshipRaceResultView.swift
//  Redline
//
//  Created by Riley Koo on 9/28/26.
//

import SwiftUI

struct ChampionshipResultsView: View {
    @EnvironmentObject var store: ChampionshipDataStore
    let session: ChampionshipPickerSession

    var body: some View {
        Group {
            switch session.resultsKind {
            case .race, .sprint:
                if store.raceResults.isEmpty {
                    ProgressView("Loading results…")
                } else {
                    List(store.raceResults) { result in
                        NavigationLink(
                            value: Destination.raceStory(session.round, result.driver.driverId, store)
                        ) {
                            RaceResultRow(result: result)
                        }
                    }
                    .listStyle(.plain)
                }

            case .qualifying:
                if let error = store.error {
                    VStack(spacing: 8) {
                        Text("Couldn't load qualifying results").font(.headline)
                        Text(error).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding()
                } else if store.qualifyingResults.isEmpty {
                    ProgressView("Loading results…")
                } else {
                    List(store.qualifyingResults) { result in
                        QualifyingResultRow(result: result)
                    }
                    .listStyle(.plain)
                }

            case nil:
                ContentUnavailableView(
                    "No results available",
                    systemImage: "questionmark.circle",
                    description: Text("Jolpica doesn't publish results for this session.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ExportMenu(source: self)
            }
        }
        .navigationTitle("\(session.raceName) · \(session.sessionName)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: session.id) {
            guard let kind = session.resultsKind else { return }
            await store.fetchSessionResults(round: session.round, kind: kind)
        }
    }
}

extension ChampionshipResultsView: Exportable {
    @ViewBuilder
    var exportContent: some View {
        let raceName = store.races.first { $0.round == session.round }?.raceName ?? "Race"

        switch session.resultsKind {
        case .qualifying:
            ClassificationExportLayout(
                title: "\(raceName) Qualifying",
                entries: store.qualifyingResults.map(\.exportEntry)
            )
        case .sprint:
            ClassificationExportLayout(
                title: "\(raceName) Sprint Classification",
                entries: store.raceResults.map(\.exportEntry)
            )
        default:
            ClassificationExportLayout(
                title: "\(raceName) Classification",
                entries: store.raceResults.map(\.exportEntry)
            )
        }
    }

    var exportFilename: String {
        let prefix = session.resultsKind == .qualifying ? "Qualifying" : "RaceResults"
        return "\(prefix)-\(session.round)"
    }
}

// Reuses the row you already have in ChampionshipRaceResultView.swift for race/sprint.
// (RaceResultRow is `private` there right now — change it to `fileprivate` won't help
// across files, so either make it internal or move it into this file.)

private struct QualifyingResultRow: View {
    let result: ChampionshipQualifyingResult
    var position: Int { Int(result.position) ?? 0 }

    var body: some View {
        HStack(spacing: 12) {
            Text(result.position)
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(position <= 3 ? Color(hex: result.teamColor) : .secondary)
                .frame(width: 28, alignment: .center)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: result.teamColor))
                .opacity(1.0)
                .frame(width: 3, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(result.driver.givenName) \(result.driver.familyName)")
                    .font(.subheadline.weight(.semibold))
                Text(result.constructor.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                qualiTime("Q3", result.q3)
                qualiTime("Q2", result.q2)
                qualiTime("Q1", result.q1)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func qualiTime(_ label: String, _ time: String?) -> some View {
        if let time {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(labelToColor(label))
                Text(time)
                    .font(.caption.monospacedDigit())
            }
        }
    }
    
    private func labelToColor(_ label: String) -> Color {
        if label == "Q1" { return .yellow }
        if label == "Q2" { return .green }
        if label == "Q3" { return .purple }
        return .gray
    }
}

private struct RaceResultRow: View {
    let result: ChampionshipRaceResult

    var position: Int { Int(result.position) ?? 0 }
    var didFinish: Bool { result.status == "Finished" || result.status.contains("Lap") }

    var body: some View {
        HStack(spacing: 12) {
            Text(result.position)
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(position <= 3 ? Color(hex: result.teamColor) : .secondary)
                .frame(width: 28, alignment: .center)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: result.teamColor))
                .opacity(didFinish ? 1.0 : 0.5)
                .frame(width: 3, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.driverName)
                    .font(.subheadline.weight(.semibold))
                Text(result.constructorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !didFinish {
                    Text(result.status)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(result.points)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text("pts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct RaceResultsTab: View {
    @EnvironmentObject var store: ChampionshipDataStore
    @Environment(Router.self) private var router
    @Binding var selectedRound: String?
    @State private var showSpoilerWarning = true
    @State private var contentUnlocked = false

    var body: some View {
        Group {
            if contentUnlocked {
                ChampionshipSessionPickerView { session in
                    selectedRound = session.round
                    router.push(Destination.raceResults(session, store))
                }
            } else {
                Color.clear
            }
        }
        .spoilerWarning(isPresented: $showSpoilerWarning, title: "Race Results") {
            contentUnlocked = true
        }
    }
}
