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

    private var targetRace: ChampionshipRace? {
        race ?? championshipStore.nextRace
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
                        ForEach(viewModel.sessionWeathers) { sw in
                            SessionWeatherRow(sessionWeather: sw)
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

                    if let markURL = viewModel.attributionMarkURL,
                       let legalURL = viewModel.attributionLegalURL {
                        Link(destination: legalURL) {
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
            guard let targetRace else { return }
            await viewModel.loadWeather(for: targetRace)
            await viewModel.loadAttribution()
        }
        .refreshable {
            guard let targetRace else { return }
            await viewModel.loadWeather(for: targetRace)
        }
        .onAppear {
            Task {
                await championshipStore.refresh()
            }
        }
    }
}

private struct SessionWeatherRow: View {
    let sessionWeather: SessionWeather

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d · HH:mm"
        f.timeZone = .current
        return f.string(from: sessionWeather.sessionDate)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sessionWeather.sessionName)
                    .font(.headline)
                Text(timeString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let symbolName = sessionWeather.symbolName {
                Image(systemName: symbolName)
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
            }

            VStack(alignment: .trailing, spacing: 4) {
                if let temp = sessionWeather.temperature {
                    Text(temp.formatted(
                        .measurement(
                            width: .narrow,
                            usage: .weather,
                            numberFormatStyle: .number.precision(.fractionLength(2))
                        )))
                        .font(.headline)
                    if let chance = sessionWeather.precipitationChance {
                        Label("\(Int(chance * 100))%", systemImage: "drop.fill")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
                else {
                    Text("Not available yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
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
