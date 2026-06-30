//
//  ScheduleView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/16/26.
//


import SwiftUI

struct ChampionshipScheduleView: View {
    @EnvironmentObject var store: ChampionshipDataStore

    var pastRaces: [ChampionshipRace] { store.races.filter { $0.isPast } }
    var upcomingRaces: [ChampionshipRace] { store.races.filter { !$0.isPast } }

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoadingSchedule && store.races.isEmpty {
                    ProgressView("Loading schedule…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if let next = store.nextRace {
                            ChampionshipNextRaceBanner(race: next, countdown: store.nextRaceCountdown)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }

                        if !upcomingRaces.isEmpty {
                            Section("Upcoming") {
                                ForEach(upcomingRaces) { race in
                                    ChampionshipRaceRow(race: race, isPast: false)
                                }
                            }
                        }

                        if !pastRaces.isEmpty {
                            Section("Completed") {
                                ForEach(pastRaces.reversed()) { race in
                                    ChampionshipRaceRow(race: race, isPast: true)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("2026 Season")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if store.isLoadingSchedule {
                        ProgressView()
                    } else {
                        Button {
                            Task { await store.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .onAppear {
                if !store.isLoadingSchedule && store.races.isEmpty {
                    Task {
                        await store.refresh()
                    }
                }
            }
        }
    }
}

private struct ChampionshipNextRaceBanner: View {
    let race: ChampionshipRace
    let countdown: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Next Race", systemImage: "flag.checkered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let c = countdown {
                    Text(c)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.red, in: Capsule())
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(race.flagEmoji) \(race.raceName)")
                        .font(.title3.weight(.bold))
                    Text("\(race.circuit.location.locality), \(race.circuit.location.country)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(race.formattedDate)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.red)
                }
                
                Spacer()
                
                ChampionshipTrackView(trackName: race.circuit.location.locality)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ChampionshipRaceRow: View {
    let race: ChampionshipRace
    let isPast: Bool
    let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f
    }()
    let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack {
            HStack(spacing: 14) {
                Text(race.round)
                    .font(.caption.weight(.bold))
                    .foregroundColor(isPast ? .secondary : .white)
                    .frame(width: 28, height: 28)
                    .background(isPast ? Color.secondary.opacity(0.15) : Color.red, in: Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(race.flagEmoji) \(race.raceName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isPast ? .secondary : .primary)
                    Text("\(race.circuit.location.locality) · \(race.formattedDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if race.sprint != nil {
                    Text("Sprint")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: Capsule())
                }
                
                Spacer()
                
                ChampionshipTrackView(trackName: race.circuit.location.locality)
                
                if isPast {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green.opacity(0.7))
                        .font(.caption)
                }
            }
            .padding(.vertical, 2)
            HStack {
                ForEach(race.allSessions, id: \.name) { session in
                    VStack {
                        Text(session.name)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .opacity(0.85)
                        Spacer()
                        Text(session.session.dateTime.map { dayFormatter.string(from: $0) } ?? "Not loaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(session.session.dateTime.map { timeFormatter.string(from: $0) } ?? "Not loaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}


#Preview {
    ChampionshipScheduleView()
}
