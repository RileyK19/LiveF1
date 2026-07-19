//
//  WeatherViewModel.swift
//  LiveF1
//
//  Created by Riley Koo on 7/19/26.
//

import SwiftUI
import WeatherKit
import CoreLocation
import Combine

// MARK: - View Model

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published var sessionWeathers: [SessionWeather] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let weatherService = WeatherService.shared
    private let geocoder = CLGeocoder()

    /// The schedule API doesn't return session length, so we assume typical durations
    /// to define each session's end time / window.
    private func duration(for sessionName: String) -> TimeInterval {
        switch sessionName {
        case "Race":
            return 2 * 3600
        case "Sprint":
            return 1 * 3600
        default: // FP1, FP2, FP3, Quali, SQ
            return 1 * 3600
        }
    }

    func loadWeather(for race: ChampionshipRace) async {
        isLoading = true
        errorMessage = nil
        sessionWeathers = []
        defer { isLoading = false }

        let query = "\(race.circuit.circuitName), \(race.circuit.location.locality), \(race.circuit.location.country)"
        guard let location = await geocode(query) else {
            errorMessage = "Couldn't locate this circuit."
            return
        }

        do {
            let sessionDates = race.allSessions.compactMap { $0.session.dateTime }
            let latestSessionEnd = sessionDates.max()?.addingTimeInterval(2 * 3600) ?? Date().addingTimeInterval(10 * 86400)

            let hourly = try await weatherService.weather(
                for: location,
                including: .hourly(startDate: Date(), endDate: latestSessionEnd)

            )
            var results: [SessionWeather] = []
            
            print("Hourly forecast entries: \(hourly.count)")
            print("Hourly forecast range: \(hourly.first?.date.description ?? "nil") to \(hourly.last?.date.description ?? "nil")")


            for (name, session) in race.allSessions {
                guard let start = session.dateTime else { continue }
                let end = start.addingTimeInterval(duration(for: name))

                // Keep only hourly readings that fall inside [start, end] — nothing before the session.
                var hoursInWindow = hourly.filter { $0.date >= start && $0.date <= end }

                // If the session is shorter than an hour and lands between two hourly readings,
                // fall back to the single closest reading rather than showing nothing.
                if hoursInWindow.isEmpty {
                    if let closest = hourly.min(by: {
                        abs($0.date.timeIntervalSince(start)) < abs($1.date.timeIntervalSince(start))
                    }) {
                        hoursInWindow = [closest]
                    }
                }

                guard !hoursInWindow.isEmpty else { continue }

                let avgTempValue = hoursInWindow.map { $0.temperature.value }.reduce(0, +) / Double(hoursInWindow.count)
                let unit = hoursInWindow.first!.temperature.unit
                let maxPrecipChance = hoursInWindow.map { $0.precipitationChance }.max() ?? 0
                let representative = hoursInWindow.first!

                results.append(
                    SessionWeather(
                        sessionName: name,
                        sessionDate: start,
                        temperature: Measurement(value: avgTempValue, unit: unit),
                        precipitationChance: maxPrecipChance,
                        symbolName: representative.symbolName
                    )
                )
            }

            sessionWeathers = results
        } catch {
            errorMessage = "Weather unavailable: \(error.localizedDescription)"
        }
    }

    private func geocode(_ query: String) async -> CLLocation? {
        await withCheckedContinuation { continuation in
            geocoder.geocodeAddressString(query) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.location)
            }
        }
    }
}
