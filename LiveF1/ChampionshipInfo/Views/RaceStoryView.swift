//
//  RaceStoryView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/26/26.
//

import SwiftUI
import Charts

struct RaceStoryView: View {
    @EnvironmentObject var store: ChampionshipDataStore
    var selectedRound: String?
    var selectedDriverId: String?
    @State private var showSpoilerWarning = true
//    @State private var contentUnlocked = false

    private var pastRaces: [ChampionshipRace] {
        store.races.filter { $0.isPast }
    }

    private var driverInfo: [(id: String, name: String, color: Color)] {
        store.driverStandings.map { standing in
            (standing.driver.driverId,
             standing.driver.code ?? standing.driver.familyName,
             Color(hex: standing.teamColor))
        }
    }

    private var driverLookup: [String: (name: String, color: Color)] {
        Dictionary(uniqueKeysWithValues: driverInfo.map { ($0.id, ($0.name, $0.color)) })
    }
    
    private var dashed: Set<String> {
        var seen: Set<String> = []
        var ret: Set<String> = []
        for standing in store.driverStandings.sorted(by: { $0.points < $1.points }) {
            if seen.contains(standing.teamColor) {
                ret.insert(standing.driver.driverId)
            } else {
                seen.insert(standing.teamColor)
            }
        }
        return ret
    }

    private var maxPosition: Int {
        store.lapPositions.map(\.position).max() ?? 20
    }

    var body: some View {
        Group {
//            if contentUnlocked {
                VStack(spacing: 0) {
//                    ScrollView(.horizontal, showsIndicators: false) {
//                        HStack(spacing: 8) {
//                            ForEach(pastRaces, id: \.self) { race in
//                                Button {
//                                    selectedRound = race.round
//                                } label: {
//                                    Text(race.raceName)
//                                        .font(.caption.weight(.medium))
//                                        .padding(.horizontal, 12)
//                                        .padding(.vertical, 6)
//                                        .background(selectedRound == race.round ? Color.accentColor : Color(.secondarySystemBackground))
//                                        .foregroundStyle(selectedRound == race.round ? .white : .primary)
//                                        .clipShape(Capsule())
//                                }
//                                .buttonStyle(.plain)
//                            }
//                        }
//                        .padding(10)
//                    }

                    if store.isLoadingLaps {
                        Spacer()
                        ProgressView("Loading lap data…")
                        Spacer()
                    } else if store.lapPositions.isEmpty {
                        Spacer()
                        Text("No lap data available for this race")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    } else {
                        chart
                            .padding()
                        Spacer()
                    }
                }
                .onAppear {
                    let tmpRound = selectedRound ?? pastRaces.last?.round
                        
                    guard let tmpRound = tmpRound else { return }
                    Task { await store.fetchLapPositions(round: tmpRound) }
                }
//                .onChange(of: selectedRound) { _, newRound in
//                    guard let newRound else { return }
//                    Task { await store.fetchLapPositions(round: newRound) }
//                }
//            } else {
//                Color.clear
//            }
        }
//        .navigationTitle("Race Story")
        .navigationTitle("Race Story: Round \(selectedRound ?? "")")
//        .spoilerWarning(isPresented: $showSpoilerWarning, title: "Race Story") {
//            contentUnlocked = true
//        }
    }

    private var chart: some View {
        Chart {
            ForEach(store.lapPositions) { point in
                LineMark(
                    x: .value("Lap", point.lap),
                    y: .value("Position", point.position)
                )
                .foregroundStyle(by: .value("Driver", driverLookup[point.driverId]?.name ?? point.driverId))
                .interpolationMethod(.monotone)
//                .lineStyle(StrokeStyle(lineWidth: selectedDriverId == point.driverId ? 4 : 2))
                .lineStyle(StrokeStyle(
                    lineWidth: selectedDriverId == point.driverId ? 4 : 2,
                    dash: dashed.contains(point.driverId) ? [4] : []
                ))
                .opacity(selectedDriverId == point.driverId ? 1.0 : 0.85)
            }
        }
        .chartForegroundStyleScale(
            domain: driverInfo.map(\.name),
            range: driverInfo.map(\.color)
        )
        .chartYScale(domain: [maxPosition, 1])
        .chartYAxis {
            AxisMarks(values: .stride(by: 1))
        }
        .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
        .frame(height: 320)
    }
}

#Preview {
    NavigationStack { RaceStoryView() }
}
