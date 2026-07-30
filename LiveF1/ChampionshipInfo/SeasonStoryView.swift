//
//  SeasonStoryView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/26/26.
//

import SwiftUI
import Charts

struct SeasonStoryView: View {
    @EnvironmentObject var store: ChampionshipDataStore
    @State private var showSpoilerWarning = true
    @State private var contentUnlocked = false
    @State private var selectedDriverIds: Set<String> = []

    // Driver order/colors taken from the most recent round we have
    private var latestStandings: [ChampionshipDriverStanding] {
        store.standingsHistory.max(by: { $0.round < $1.round })?.standings
            .sorted { (Int($0.position) ?? 99) < (Int($1.position) ?? 99) } ?? []
    }

    private var maxPosition: Int {
        store.standingsHistory
            .flatMap { $0.standings.compactMap { Int($0.position) } }
            .max() ?? 20
    }

    var body: some View {
        Group {
            if contentUnlocked {
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(latestStandings) { standing in
                                let id = standing.driver.driverId
                                Button {
                                    toggle(id)
                                } label: {
                                    Text(standing.driver.code ?? standing.driver.familyName)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedDriverIds.contains(id) ? Color(hex: standing.teamColor) : Color(.secondarySystemBackground))
                                        .foregroundStyle(selectedDriverIds.contains(id) ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                    }

                    if store.standingsHistory.isEmpty {
                        Spacer()
                        ProgressView("Loading season history…")
                        Spacer()
                    } else {
                        chart
                            .padding()
                        Spacer()
                    }
                }
                .onAppear {
                    if selectedDriverIds.isEmpty {
                        // default to top 6 so the chart isn't a rainbow mess
                        selectedDriverIds = Set(latestStandings.prefix(6).map(\.driver.driverId))
                    }
                    if store.standingsHistory.isEmpty {
                        Task { await store.fetchStandingsHistory() }
                    }
                }
            } else {
                Color.clear
            }
        }
        .navigationTitle("Season Story")
        .spoilerWarning(isPresented: $showSpoilerWarning, title: "Season Story") {
            contentUnlocked = true
        }
    }

    private func toggle(_ id: String) {
        if selectedDriverIds.contains(id) {
            selectedDriverIds.remove(id)
        } else {
            selectedDriverIds.insert(id)
        }
    }

    private struct SeasonLinePoint: Identifiable {
        let id = UUID()
        let driverId: String
        let round: Int
        let position: Int
        let color: Color
        let isSelected: Bool
    }

    private var linePoints: [SeasonLinePoint] {
        store.standingsHistory.flatMap { entry -> [SeasonLinePoint] in
            entry.standings.compactMap { standing -> SeasonLinePoint? in
                guard let position = Int(standing.position) else { return nil }
                let id = standing.driver.driverId
                let selected = selectedDriverIds.isEmpty || selectedDriverIds.contains(id)
                return SeasonLinePoint(
                    driverId: id,
                    round: entry.round,
                    position: position,
                    color: selected ? Color(hex: standing.teamColor) : Color.secondary.opacity(0.25),
                    isSelected: selected
                )
            }
        }
    }

    private var chart: some View {
        Chart(linePoints) { point in
            LineMark(
                x: .value("Round", point.round),
                y: .value("Position", point.position),
                series: .value("Driver", point.driverId)
            )
            .foregroundStyle(point.color)
            .lineStyle(StrokeStyle(lineWidth: point.isSelected ? 2.5 : 1))
            .interpolationMethod(.monotone)
            .symbol(.circle)
        }
        .chartYScale(domain: [maxPosition, 1])
        .chartYAxis {
            AxisMarks(values: .stride(by: 1))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 1))
        }
        .frame(height: 320)
    }
}

#Preview {
    NavigationStack { SeasonStoryView() }
}
