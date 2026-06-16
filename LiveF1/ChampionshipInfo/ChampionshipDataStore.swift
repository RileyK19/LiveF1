//
//  ChampionshipDataStore.swift
//  LiveF1
//
//  Created by Riley Koo on 6/16/26.
//

import Foundation
import Combine

@MainActor
final class ChampionshipDataStore: ObservableObject {

    // MARK: - Published State

    @Published var races: [ChampionshipRace] = []
    @Published var driverStandings: [ChampionshipDriverStanding] = []
    @Published var constructorStandings: [ChampionshipConstructorStanding] = []
    @Published var isLoadingSchedule = false
    @Published var isLoadingStandings = false
    @Published var error: String?
    @Published var lastUpdated: Date?

    // MARK: - Private

    private let base = "https://api.jolpi.ca/ergast/f1"
    private let season = "current"
    private let defaults = UserDefaults.standard

    private enum CacheKey {
        static let schedule = "f1_cache_schedule"
        static let driverStandings = "f1_cache_driver_standings"
        static let constructorStandings = "f1_cache_constructor_standings"
        static let lastUpdated = "f1_cache_last_updated"
    }

    // MARK: - Init

    init() {
        loadFromCache()
    }

    // MARK: - Public API

    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchSchedule(forceRefresh: true) }
            group.addTask { await self.fetchDriverStandings(forceRefresh: true) }
            group.addTask { await self.fetchConstructorStandings(forceRefresh: true) }
        }
    }

    func fetchAllIfNeeded() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchSchedule(forceRefresh: false) }
            group.addTask { await self.fetchDriverStandings(forceRefresh: false) }
            group.addTask { await self.fetchConstructorStandings(forceRefresh: false) }
        }
    }

    // MARK: - Next Race

    var nextRace: ChampionshipRace? {
        races.first { $0.isNext }
    }

    var nextRaceCountdown: String? {
        guard let next = nextRace, let date = next.raceDate else { return nil }
        let diff = Calendar.current.dateComponents([.day, .hour], from: Date(), to: date)
        if let days = diff.day, days > 0 {
            return "\(days)d \(diff.hour ?? 0)h"
        } else if let hours = diff.hour, hours > 0 {
            return "\(hours)h"
        }
        return "Soon"
    }

    // MARK: - Fetch Schedule

    private func fetchSchedule(forceRefresh: Bool) async {
        if !forceRefresh, let cached: [ChampionshipRace] = loadCache(key: CacheKey.schedule) {
            self.races = cached
            return
        }

        isLoadingSchedule = true
        defer { isLoadingSchedule = false }

        do {
            let url = URL(string: "\(base)/\(season).json?limit=100")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ChampionshipScheduleResponse.self, from: data)
            let fetched = decoded.mrData.raceTable.races
            self.races = fetched
            saveCache(fetched, key: CacheKey.schedule)
            updateLastUpdated()
        } catch {
            self.error = "Schedule: \(error.localizedDescription)"
        }
    }

    // MARK: - Fetch Driver Standings

    private func fetchDriverStandings(forceRefresh: Bool) async {
        if !forceRefresh, let cached: [ChampionshipDriverStanding] = loadCache(key: CacheKey.driverStandings) {
            self.driverStandings = cached
            return
        }

        isLoadingStandings = true
        defer { isLoadingStandings = false }

        do {
            let url = URL(string: "\(base)/\(season)/driverStandings.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ChampionshipStandingsResponse.self, from: data)
            let standings = decoded.mrData.standingsTable.standingsLists.first?.driverStandings ?? []
            self.driverStandings = standings
            saveCache(standings, key: CacheKey.driverStandings)
            updateLastUpdated()
        } catch {
            self.error = "Driver standings: \(error.localizedDescription)"
        }
    }

    // MARK: - Fetch Constructor Standings

    private func fetchConstructorStandings(forceRefresh: Bool) async {
        if !forceRefresh, let cached: [ChampionshipConstructorStanding] = loadCache(key: CacheKey.constructorStandings) {
            self.constructorStandings = cached
            return
        }

        do {
            let url = URL(string: "\(base)/\(season)/constructorStandings.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ChampionshipStandingsResponse.self, from: data)
            let standings = decoded.mrData.standingsTable.standingsLists.first?.constructorStandings ?? []
            self.constructorStandings = standings
            saveCache(standings, key: CacheKey.constructorStandings)
            updateLastUpdated()
        } catch {
            self.error = "Constructor standings: \(error.localizedDescription)"
        }
    }

    // MARK: - Cache Helpers

    private func saveCache<T: Codable>(_ value: T, key: String) {
        let entry = ChampionshipCacheEntry(data: value, timestamp: Date())
        if let encoded = try? JSONEncoder().encode(entry) {
            defaults.set(encoded, forKey: key)
        }
    }

    private func loadCache<T: Codable>(key: String) -> T? {
        guard let data = defaults.data(forKey: key),
              let entry = try? JSONDecoder().decode(ChampionshipCacheEntry<T>.self, from: data),
              !entry.isExpired else { return nil }
        return entry.data
    }

    private func loadFromCache() {
        if let cached: [ChampionshipRace] = loadCache(key: CacheKey.schedule) {
            self.races = cached
        }
        if let cached: [ChampionshipDriverStanding] = loadCache(key: CacheKey.driverStandings) {
            self.driverStandings = cached
        }
        if let cached: [ChampionshipConstructorStanding] = loadCache(key: CacheKey.constructorStandings) {
            self.constructorStandings = cached
        }
        if let ts = defaults.object(forKey: CacheKey.lastUpdated) as? Date {
            self.lastUpdated = ts
        }
    }

    private func updateLastUpdated() {
        let now = Date()
        lastUpdated = now
        defaults.set(now, forKey: CacheKey.lastUpdated)
    }

    func clearCache() {
        [CacheKey.schedule, CacheKey.driverStandings,
         CacheKey.constructorStandings, CacheKey.lastUpdated].forEach {
            defaults.removeObject(forKey: $0)
        }
    }
}
