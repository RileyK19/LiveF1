//
//  SessionPickerView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//

import SwiftUI

extension F1PredictorSession: PickableSession {
    var pickerTitle: String { countryName }
    var pickerSubtitle: String { circuitShortName }
    var pickerTypeName: String { sessionName }
    var pickerDate: Date? { dateStart }
    var pickerSearchStrings: [String] { [countryName, circuitShortName] }

    var pickerDisabledReason: String? {
        guard !hasLaps else { return nil }
        if let dateStart, dateStart >= .now { return "In future" }
        if isCancelled { return "Cancelled" }
        return "Unavailable"
    }
}

struct SessionPickerView: View {
    @StateObject private var viewModel: SessionPickerViewModel

    let title: String
    let route: (F1PredictorSession) -> Void

    init(
        title: String = "2026 Season",
        sessionType: String? = "Race",
        route: @escaping (F1PredictorSession) -> Void
    ) {
        self.title = title
        self.route = route
        _viewModel = StateObject(wrappedValue: SessionPickerViewModel(sessionType: sessionType))
    }

    var body: some View {
        SessionPickerContent(
            title: title,
            items: viewModel.sessions,
            isLoading: viewModel.isLoading,
            error: viewModel.error,
            errorFootnote: "Note: Data not available during live sessions due to OpenF1 restrictions",
            onRetry: { Task { await viewModel.load() } },
            onSelect: route
        )
        .task { await viewModel.load() }
    }
}

//
//import SwiftUI
//
////struct SessionPickerView<Destination: View>: View {
//struct SessionPickerView: View {
//    @StateObject private var viewModel: SessionPickerViewModel
//
//    let title: String
////    let destination: (F1PredictorSession) -> Destination
//    let route: (F1PredictorSession) -> Void
//
//    @State private var searchText = ""                              // NEW
//    @State private var selectedSessionTypes: Set<String> = []        // NEW: empty = show all
//
//    init(
//        title: String = "2026 Season",
//        sessionType: String? = "Race",
//        route: @escaping (F1PredictorSession) -> Void
////        @ViewBuilder destination: @escaping (F1PredictorSession) -> Destination
//    ) {
//        self.title = title
////        self.destination = destination
//        self.route = route
//        _viewModel = StateObject(wrappedValue: SessionPickerViewModel(sessionType: sessionType))
//    }
//
//    // Distinct session types available to filter by, derived from loaded data
//    private var availableSessionTypes: [String] {
//        Array(Set(viewModel.sessions.map(\.sessionName))).sorted()
//    }
//
//    private var filteredSessions: [F1PredictorSession] {
//        viewModel.sessions
////            .filter { $0.hasLaps }
//            .filter { selectedSessionTypes.isEmpty || selectedSessionTypes.contains($0.sessionName) }
//            .filter { searchText.isEmpty ||
//                $0.countryName.localizedCaseInsensitiveContains(searchText) ||
//                $0.circuitShortName.localizedCaseInsensitiveContains(searchText)
//            }
//    }
//
//    var body: some View {
////        NavigationStack {
//            Group {
//                if viewModel.isLoading {
//                    ProgressView("Loading races...")
//                } else if let error = viewModel.error {
//                    VStack(spacing: 12) {
//                        Text("Failed to load sessions")
//                            .font(.headline)
//                        Text(error)
//                            .font(.caption)
//                            .foregroundStyle(.secondary)
//                        Text("Note: Data not available during live sessions due to OpenF1 restrictions")
//                            .font(.caption2)
//                            .foregroundStyle(.secondary)
//                        Button("Retry") {
//                            Task { await viewModel.load() }
//                        }
//                    }
//                } else {
//                    VStack(spacing: 0) {
//                        // NEW: horizontal chip filter for session type
//                        if availableSessionTypes.count > 1 {
//                            ScrollView(.horizontal, showsIndicators: false) {
//                                HStack(spacing: 8) {
//                                    Button {
//                                        selectedSessionTypes = []
//                                    } label: {
//                                        Text("All")
//                                            .font(.caption.weight(.medium))
//                                            .padding(.horizontal, 12)
//                                            .padding(.vertical, 6)
//                                            .background(selectedSessionTypes == [] ? Color.accentColor : Color(.secondarySystemBackground))
//                                            .foregroundStyle(selectedSessionTypes == [] ? .white : .primary)
//                                            .clipShape(Capsule())
//                                    }
//                                    .buttonStyle(.plain)
//                                    ForEach(availableSessionTypes, id: \.self) { type in
//                                        let isSelected = selectedSessionTypes.contains(type)
//                                        Button {
//                                            if isSelected {
//                                                selectedSessionTypes.remove(type)
//                                            } else {
//                                                selectedSessionTypes.insert(type)
//                                            }
//                                        } label: {
//                                            Text(type)
//                                                .font(.caption.weight(.medium))
//                                                .padding(.horizontal, 12)
//                                                .padding(.vertical, 6)
//                                                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
//                                                .foregroundStyle(isSelected ? .white : .primary)
//                                                .clipShape(Capsule())
//                                        }
//                                        .buttonStyle(.plain)
//                                    }
//                                }
//                                .padding(.horizontal)
//                                .padding(.vertical, 8)
//                            }
//                        }
//
//                        List(filteredSessions) { session in
////                            NavigationLink(destination: destination(session)) {
//                            Button {
//                                if session.hasLaps {
//                                    route(session)
//                                }
//                            } label: {
//                                SessionRowView(session: session, disabled: !session.hasLaps)
//                            }
//                            .buttonStyle(.plain)
//                            .disabled(!session.hasLaps)
//                        }
//                        .listStyle(.insetGrouped)
//                    }
//                }
//            }
//            .navigationTitle(title)
//            .searchable(text: $searchText, prompt: "Search country or circuit")   // NEW
//            .task { await viewModel.load() }
////        }
//    }
//}
//
//struct SessionRowView: View {
//    let session: F1PredictorSession
//    var disabled: Bool = false
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 4) {
//            HStack {
//                Text(session.countryName)
//                    .font(.headline)
//                Spacer()
//                Text(session.sessionName)
//                    .font(.caption2.weight(.semibold))
//                    .padding(.horizontal, 8)
//                    .padding(.vertical, 3)
//                    .background(sessionColor.opacity(0.15))
//                    .foregroundStyle(sessionColor)
//                    .clipShape(Capsule())
//            }
//            HStack {
//                Text(session.circuitShortName)
//                    .font(.subheadline)
//                    .foregroundStyle(.secondary)
//                if disabled {
//                    Spacer()
//                    Text(session.dateStart ?? .now >= .now ? "In future" : session.isCancelled ? "Cancelled" : "Unavailable")
//                        .font(.caption2.weight(.semibold))
//                        .padding(.horizontal, 8)
//                        .padding(.vertical, 3)
//                        .background(.secondary.opacity(0.15))
//                        .foregroundStyle(.secondary)
//                        .clipShape(Capsule())
//                }
//            }
//            if let date = session.dateStart {
//                Text(date.formatted(date: .abbreviated, time: .omitted))
//                    .font(.caption)
//                    .foregroundStyle(.tertiary)
//            }
//        }
//        .padding(.vertical, 4)
//        .opacity(disabled ? 0.4 : 1)
//    }
//
//    private var sessionColor: Color {
//        switch session.sessionName {
//        case "Race": return .red
//        case "Qualifying": return .blue
//        case "Sprint": return .orange
//        case "Sprint Qualifying", "Sprint Shootout": return .purple
//        default: return .secondary // Practice 1/2/3, etc.
//        }
//    }
//}
