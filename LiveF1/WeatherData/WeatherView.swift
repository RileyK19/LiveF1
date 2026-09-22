//
//  WeatherView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/19/26.
//

import SwiftUI
import WeatherKit
import CoreLocation

// MARK: - View

struct WeatherView: View {
    /// Optional explicit race (e.g. tapped from a schedule list). If nil, falls back
    /// to `championshipStore.nextRace`.
    var race: ChampionshipRace? = nil

    @EnvironmentObject private var championshipStore: ChampionshipDataStore
    @StateObject private var viewModel = WeatherViewModel()
    @Environment(\.colorScheme) private var colorScheme

    private var targetRace: ChampionshipRace? {
        if let mostRecentPast = championshipStore.races
            .filter({ $0.isPast })
            .sorted(by: { ($0.raceDate ?? .distantPast) < ($1.raceDate ?? .distantPast) })
            .last,
           let date = mostRecentPast.raceDate,
           Calendar.current.isDateInToday(date) {
            return mostRecentPast
        }
        return race ?? championshipStore.nextRace
    }

    var body: some View {
        List {
            Section {
                if let targetRace {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.secondary)
                    } else if viewModel.sessionWeathers.isEmpty {
                        Text("No session weather available yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        if let currentSW = viewModel.currentAsSessionWeather {
                            SessionWeatherRow(sessionWeather: currentSW, viewModel: viewModel)
                        }
                        ForEach(viewModel.sessionWeathers) { sw in
                            SessionWeatherRow(sessionWeather: sw, viewModel: viewModel)
                        }
                    }
                } else if championshipStore.isLoadingSchedule {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    Text("No upcoming race found.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(targetRace?.raceName ?? "Weather")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hourly forecasts are only available within about 10 days of the session.")


                    if let attribution = viewModel.attribution {
                        let markURL = colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL
                        Link(destination: attribution.legalPageURL) {
                            AsyncImage(url: markURL) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                EmptyView()
                            }
                            .frame(height: 20)
                        }
                    }
                }
            }
        }
        .navigationTitle("Weather")
        .task(id: targetRace?.round) {
            await championshipStore.refresh()
            guard let targetRace else { return }
            await viewModel.loadWeather(for: targetRace)
            await viewModel.loadCurrentWeather()
            await viewModel.loadAttribution()
        }
        .refreshable {
            guard let targetRace else { return }
            await viewModel.loadWeather(for: targetRace)
            await viewModel.loadCurrentWeather()
        }
//        .onAppear {
//            Task {
//                await championshipStore.refresh()
//            }
//        }
    }
}

// MARK: - Preview

/// Builds a date string / time string exactly `daysFromNow` days ahead, in the
/// "yyyy-MM-dd" / "HH:mm:ssZ" (UTC) format that `ChampionshipSession.dateTime` expects.
private func previewDateAndTime(daysFromNow: Int) -> (date: String, time: String) {
    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.timeZone = TimeZone(identifier: "UTC")!

    let futureDate = utcCalendar.date(byAdding: .day, value: daysFromNow, to: Date())!

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(identifier: "UTC")
    dateFormatter.dateFormat = "yyyy-MM-dd"

    let timeFormatter = DateFormatter()
    timeFormatter.locale = Locale(identifier: "en_US_POSIX")
    timeFormatter.timeZone = TimeZone(identifier: "UTC")
    timeFormatter.dateFormat = "HH:mm:ss'Z'"

    return (dateFormatter.string(from: futureDate), timeFormatter.string(from: futureDate))
}

/// A store preloaded with one synthetic race exactly 1 week out, so the preview
/// exercises the same `championshipStore.nextRace` path the real app uses,
/// without hitting the network.
@MainActor
private func previewStore() -> ChampionshipDataStore {
    let (raceDate, raceTime) = previewDateAndTime(daysFromNow: 7)
    let store = ChampionshipDataStore()
    store.races = [
        ChampionshipRace(
            round: "1",
            raceName: "Australian Grand Prix",
            date: raceDate,
            time: raceTime,
            circuit: ChampionshipCircuit(
                circuitName: "Albert Park Circuit",
                location: ChampionshipLocation(locality: "Melbourne", country: "Australia")
            ),
            firstPractice: nil,
            secondPractice: nil,
            thirdPractice: nil,
            qualifying: nil,
            sprint: nil,
            sprintQualifying: nil
        )
    ]
    return store
}

#Preview {
    NavigationStack {
        WeatherView()
            .environmentObject(previewStore())
    }
}
