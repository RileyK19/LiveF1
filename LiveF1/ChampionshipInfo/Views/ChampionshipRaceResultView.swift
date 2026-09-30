//
//  ChampionshipRaceResultView.swift
//  Redline
//
//  Created by Riley Koo on 9/28/26.
//

import SwiftUI

struct RaceResultsTab: View {
    @EnvironmentObject var store: ChampionshipDataStore
    @Binding var selectedRound: String?
    @State private var showSpoilerWarning = true
    @State private var contentUnlocked = false

    var pastRaces: [ChampionshipRace] {
        store.races.filter { $0.isPast }
    }

    var body: some View {
        Group {
            if contentUnlocked {
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(pastRaces, id: \.self) { race in
                                Button {
                                    selectedRound = race.round as String?
                                } label: {
                                    Text(race.raceName)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedRound == race.round ? Color.accentColor : Color(.secondarySystemBackground))
                                        .foregroundStyle(selectedRound == race.round ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                    }
                    
                    if store.raceResults.isEmpty {
                        Spacer()
                        ProgressView("Loading results…")
                        Spacer()
                    } else {
                        List {
                            ForEach(store.raceResults) { result in
//                                NavigationLink {
//                                    RaceStoryView(selectedRound: selectedRound, selectedDriverId: result.driver.driverId)
//                                        .environmentObject(ChampionshipDataStore())
//                                } label: {
                                NavigationLink(value: Destination.raceStory(selectedRound, result.driver.driverId, ChampionshipDataStore())) {
                                    RaceResultRow(result: result)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .onAppear {
                    if selectedRound == nil {
                        selectedRound = pastRaces.last?.round
                    }
                }
                .onChange(of: selectedRound) { _, newRound in
                    guard let newRound else { return }
                    Task { await store.fetchRaceResults(round: newRound) }
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
