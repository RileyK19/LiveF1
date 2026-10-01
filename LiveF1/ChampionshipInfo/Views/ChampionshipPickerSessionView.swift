//
//  ChampionshipPickerSession.swift
//  Redline
//
//  Created by Riley Koo on 9/30/26.
//

import SwiftUI

// MARK: - Picker item

struct ChampionshipPickerSession: PickableSession, Hashable {
    /// What the Jolpica API can actually return results for.
    enum ResultsKind: String {
        case race       // /{round}/results.json
        case sprint     // /{round}/sprint.json
        case qualifying // /{round}/qualifying.json
    }

    let round: String
    let raceName: String
    let sessionName: String
    let date: Date?

    var id: String { "\(round)-\(sessionName)" }

    /// nil for practice sessions etc. (Jolpica has no data for them)
    var resultsKind: ResultsKind? {
        let n = sessionName.lowercased()
        if n.contains("practice") { return nil }
        if n.contains("sprint") && (n.contains("quali") || n.contains("shootout")) { return .qualifying }
        if n.contains("sprint") { return .sprint }
        if n.contains("quali") { return .qualifying }
        if n.contains("race") { return .race }
        return nil
    }

    let isPast: Bool

    // PickableSession
    var pickerTitle: String { raceName }
    var pickerSubtitle: String { "Round \(round)" }
    var pickerTypeName: String { sessionName }
    var pickerDate: Date? { date }
    var pickerSearchStrings: [String] { [raceName, sessionName] }

    var pickerDisabledReason: String? {
        guard isPast else { return "In future" }
        guard resultsKind != nil else { return "No data" }
        return nil
    }
}

// MARK: - View

struct ChampionshipSessionPickerView: View {
    @EnvironmentObject var store: ChampionshipDataStore

    let title: String
    let route: (ChampionshipPickerSession) -> Void

    init(title: String = "Race Results",
         route: @escaping (ChampionshipPickerSession) -> Void) {
        self.title = title
        self.route = route
    }

    /// Every race/sprint/qualifying session, newest first. Practice and sprint-
    /// qualifying sessions never have results on Jolpica, so they're excluded
    /// outright rather than shown disabled. Future sessions still show, but
    /// disabled ("In future"), since they'll have data once the session happens.
    private var sessions: [ChampionshipPickerSession] {
        store.races
            .flatMap { race in
                race.allSessions.map {
                    ChampionshipPickerSession(
                        round: race.round,
                        raceName: race.raceName,
                        sessionName: $0.name,
                        date: $0.session.dateTime,
                        isPast: $0.session.isPast
                    )
                }
            }
            .filter { $0.resultsKind != nil }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    var body: some View {
        SessionPickerContent(
            title: title,
            items: sessions,
            isLoading: store.isLoadingSchedule && store.races.isEmpty,
            error: store.races.isEmpty ? store.error : nil,
            searchPrompt: "Search race or session",
            onRetry: { Task { await store.refresh() } },
            onSelect: route
        )
        .task { await store.fetchAllIfNeeded() }
    }
}
