//
//  StandingsView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/16/26.
//


import SwiftUI

struct ChampionshipStandingsView: View {
    @EnvironmentObject var store: ChampionshipDataStore
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Standings", selection: $selectedTab) {
                    Text("Drivers").tag(0)
                    Text("Constructors").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)

                if store.isLoadingStandings && store.driverStandings.isEmpty {
                    Spacer()
                    ProgressView("Loading standings…")
                    Spacer()
                } else {
                    TabView(selection: $selectedTab) {
                        DriverStandingsTab()
                            .tag(0)
                        ConstructorStandingsTab()
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Standings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if store.isLoadingStandings {
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
        }
    }
}

// MARK: - Driver Standings Tab

private struct DriverStandingsTab: View {
    @EnvironmentObject var store: ChampionshipDataStore

    var leader: ChampionshipDriverStanding? { store.driverStandings.first }
    var leaderPoints: Double { Double(leader?.points ?? "0") ?? 0 }

    var body: some View {
        List {
            ForEach(store.driverStandings) { standing in
                DriverStandingRow(standing: standing, leaderPoints: leaderPoints)
            }
        }
        .listStyle(.plain)
    }
}

private struct DriverStandingRow: View {
    let standing: ChampionshipDriverStanding
    let leaderPoints: Double

    var points: Double { Double(standing.points) ?? 0 }
    var progress: Double { leaderPoints > 0 ? points / leaderPoints : 0 }
    var teamColor: Color { Color(hex: standing.teamColor) ?? .gray }
    var position: Int { Int(standing.position) ?? 0 }

    var body: some View {
        HStack(spacing: 12) {
            // Position
            Text(standing.position)
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(position <= 3 ? teamColor : .secondary)
                .frame(width: 28, alignment: .center)

            // Team color strip
            RoundedRectangle(cornerRadius: 2)
                .fill(teamColor)
                .frame(width: 3, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(standing.driver.fullName)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(standing.constructors.first?.name ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text("\(standing.wins) wins")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Points bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 4)
                        Capsule()
                            .fill(teamColor)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(standing.points)
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

// MARK: - Constructor Standings Tab

private struct ConstructorStandingsTab: View {
    @EnvironmentObject var store: ChampionshipDataStore

    var leaderPoints: Double {
        Double(store.constructorStandings.first?.points ?? "0") ?? 0
    }

    var body: some View {
        List {
            ForEach(store.constructorStandings) { standing in
                ConstructorStandingRow(standing: standing, leaderPoints: leaderPoints)
            }
        }
        .listStyle(.plain)
    }
}

private struct ConstructorStandingRow: View {
    let standing: ChampionshipConstructorStanding
    let leaderPoints: Double

    var points: Double { Double(standing.points) ?? 0 }
    var progress: Double { leaderPoints > 0 ? points / leaderPoints : 0 }
    var teamColor: Color { Color(hex: standing.teamColor) ?? .gray }
    var position: Int { Int(standing.position) ?? 0 }

    var body: some View {
        HStack(spacing: 12) {
            Text(standing.position)
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(position <= 3 ? teamColor : .secondary)
                .frame(width: 28, alignment: .center)

            RoundedRectangle(cornerRadius: 2)
                .fill(teamColor)
                .frame(width: 3, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(standing.constructor.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(standing.wins) wins · \(standing.constructor.nationality)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 4)
                        Capsule()
                            .fill(teamColor)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(standing.points)
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

#Preview {
    ChampionshipStandingsView()
}
