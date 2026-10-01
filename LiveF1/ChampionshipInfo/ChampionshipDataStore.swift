//
//  ChampionshipDataStore.swift
//  LiveF1
//
//  Created by Riley Koo on 6/16/26.
//

import Foundation
import Combine

@MainActor
final class ChampionshipDataStore: Observable, ObservableObject, Equatable, Hashable {
    public var id: UUID

    // MARK: - Published State

    @Published var races: [ChampionshipRace] = []
    @Published var driverStandings: [ChampionshipDriverStanding] = []
    @Published var constructorStandings: [ChampionshipConstructorStanding] = []
    @Published var raceResults: [ChampionshipRaceResult] = []
    @Published var qualifyingResults: [ChampionshipQualifyingResult] = []
    @Published var isLoadingSchedule = false
    @Published var isLoadingStandings = false
    @Published var error: String?
    @Published var lastUpdated: Date?
    @Published var lapPositions: [ChampionshipLapPosition] = []
    @Published var isLoadingLaps = false
    @Published var standingsHistory: [ChampionshipStandingsHistoryEntry] = []

    var mostRecentSession: (race: ChampionshipRace, name: String, session: ChampionshipSession)? {
        races
            .flatMap { race in
                race.allSessions.map { (race: race, name: $0.name, session: $0.session) }
            }
            .filter { $0.session.isPast }
            .sorted { ($0.session.dateTime ?? .distantPast) > ($1.session.dateTime ?? .distantPast) }
            .first
    }
    
    // MARK: - Private

    private let base = "https://api.jolpi.ca/ergast/f1"
    private let season = "current"
    private let defaults = UserDefaults(suiteName: "group.com.riley.livef1") ?? .standard

    private enum CacheKey {
        static let schedule = "f1_cache_schedule"
        static let driverStandings = "f1_cache_driver_standings"
        static let constructorStandings = "f1_cache_constructor_standings"
        static let lastUpdated = "f1_cache_last_updated"
        static let raceResults = "f1_cache_race_results"
    }

    // MARK: - Init

    init() {
        id = UUID()
        loadFromCache()
    }
    
    
    static func == (lhs: ChampionshipDataStore, rhs: ChampionshipDataStore) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
    
//    func scheduleNotificationsForNextRace() async {
//        guard let race = nextRace else { return }
//        await SessionNotificationManager.shared.requestAuthorizationIfNeeded()
//        await SessionNotificationManager.shared.scheduleNotifications(for: race)
//    }
    func scheduleNotificationsForNextRace(count: Int = 3) async {
        await SessionNotificationManager.shared.requestAuthorizationIfNeeded()

        let upcoming = races
            .filter { !$0.isPast }
            .sorted { ($0.raceDate ?? .distantFuture) < ($1.raceDate ?? .distantFuture) }
            .prefix(count)

        for race in upcoming {
            await SessionNotificationManager.shared.scheduleNotifications(for: race)
        }
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
            print("Saved \(fetched.count) races to shared cache")
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
    
    func fetchRaceResults(round: String, forceRefresh: Bool = false) async {
        let cacheKey = "\(CacheKey.raceResults)_\(round)"

        if !forceRefresh, let cached: [ChampionshipRaceResult] = loadCache(key: cacheKey) {
            self.raceResults = cached
            return
        }

        guard let url = URL(string: "\(base)/\(season)/\(round)/results.json") else {
            self.error = "Race results: invalid URL for round \(round)"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let mrData = json?["MRData"] as? [String: Any]
            let raceTable = mrData?["RaceTable"] as? [String: Any]
            let races = raceTable?["Races"] as? [[String: Any]]
            let resultsArray = races?.first?["Results"] as? [[String: Any]] ?? []

            let results = try resultsArray.map { obj -> ChampionshipRaceResult in
                let itemData = try JSONSerialization.data(withJSONObject: obj)
                return try JSONDecoder().decode(ChampionshipRaceResult.self, from: itemData)
            }

            self.raceResults = results
            saveCache(results, key: cacheKey)
            updateLastUpdated()
        } catch {
            self.error = "Race results: \(error.localizedDescription)"
        }
    }
    
    // MARK: Fetch stories

    func fetchLapPositions(round: String, forceRefresh: Bool = false) async {
        let cacheKey = "f1_cache_laps_\(round)"

        if !forceRefresh, let cached: [ChampionshipLapPosition] = loadCache(key: cacheKey) {
            self.lapPositions = cached
            return
        }

        isLoadingLaps = true
        defer { isLoadingLaps = false }

        var allTimings: [ChampionshipLapPosition] = []
        var offset = 0
        let limit = 100

        do {
            while true {
                guard let url = URL(string: "\(base)/\(season)/\(round)/laps.json?limit=\(limit)&offset=\(offset)") else {
                    self.error = "Lap positions: invalid URL for round \(round)"
                    break
                }
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode(ChampionshipLapsResponse.self, from: data)

                let laps = decoded.mrData.raceTable.races.first?.laps ?? []
                let flattened = laps.flatMap { lap -> [ChampionshipLapPosition] in
                    let lapNumber = Int(lap.number) ?? 0
                    return lap.timings.map {
                        ChampionshipLapPosition(driverId: $0.driverId, lap: lapNumber,
                                                 position: Int($0.position) ?? 0, time: $0.time)
                    }
                }
                allTimings.append(contentsOf: flattened)

                let total = Int(decoded.mrData.total) ?? 0
                offset += limit
                if offset >= total || laps.isEmpty { break }
            }

            self.lapPositions = allTimings
            saveCache(allTimings, key: cacheKey)
            updateLastUpdated()
        } catch {
            self.error = "Lap positions: \(error.localizedDescription)"
        }
    }

    func fetchStandingsHistory(forceRefresh: Bool = false) async {
        let cacheKey = "f1_cache_standings_history"

        if !forceRefresh, let cached: [ChampionshipStandingsHistoryEntry] = loadCache(key: cacheKey) {
            self.standingsHistory = cached
            return
        }

        // races must already be loaded so we know how many rounds have happened
        let completedRounds = races.filter { $0.isPast }.compactMap { Int($0.round) }
        guard !completedRounds.isEmpty else { return }

        var results: [ChampionshipStandingsHistoryEntry] = []

        await withTaskGroup(of: ChampionshipStandingsHistoryEntry?.self) { group in
            for round in completedRounds {
                group.addTask {
                    
                    guard let url = URL(string: "\(self.base)/\(self.season)/\(round)/driverStandings.json"),
                          let (data, _) = try? await URLSession.shared.data(from: url),
                          let decoded = try? JSONDecoder().decode(ChampionshipStandingsResponse.self, from: data),
                          let standings = decoded.mrData.standingsTable.standingsLists.first?.driverStandings
                    else { return nil }
                    return ChampionshipStandingsHistoryEntry(round: round, standings: standings)
                }
            }
            for await entry in group {
                if let entry { results.append(entry) }
            }
        }

        results.sort { $0.round < $1.round }
        self.standingsHistory = results
        saveCache(results, key: cacheKey)
        updateLastUpdated()
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
 
    /// Unified fetch for race / sprint / qualifying results, replacing the
    /// race-only fetchRaceResults for anything driven by ChampionshipSessionPickerView.
    func fetchSessionResults(
        round: String,
        kind: ChampionshipPickerSession.ResultsKind,
        forceRefresh: Bool = false
    ) async {
        switch kind {
        case .race, .sprint:
            let path = kind == .race ? "results" : "sprint"
            let resultsKey = kind == .race ? "Results" : "SprintResults"
            await fetchStandardResults(round: round, path: path, resultsKey: resultsKey, forceRefresh: forceRefresh)
        case .qualifying:
            await fetchQualifyingResults(round: round, forceRefresh: forceRefresh)
        }
    }
 
    private func fetchStandardResults(
        round: String, path: String, resultsKey: String, forceRefresh: Bool
    ) async {
        let cacheKey = "f1_cache_\(path)_\(round)"
        if !forceRefresh, let cached: [ChampionshipRaceResult] = loadCache(key: cacheKey) {
            self.raceResults = cached
            return
        }
        guard let url = URL(string: "\(base)/\(season)/\(round)/\(path).json") else {
            self.error = "\(path) results: invalid URL for round \(round)"
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let mrData = json?["MRData"] as? [String: Any]
            let raceTable = mrData?["RaceTable"] as? [String: Any]
            let races = raceTable?["Races"] as? [[String: Any]]
            let resultsArray = races?.first?[resultsKey] as? [[String: Any]] ?? []
            let results = try resultsArray.map { obj -> ChampionshipRaceResult in
                let itemData = try JSONSerialization.data(withJSONObject: obj)
                return try JSONDecoder().decode(ChampionshipRaceResult.self, from: itemData)
            }
            self.raceResults = results
            saveCache(results, key: cacheKey)
            updateLastUpdated()
        } catch {
            self.error = "\(path) results: \(error.localizedDescription)"
        }
    }
 
    private func fetchQualifyingResults(round: String, forceRefresh: Bool) async {
        let cacheKey = "f1_cache_qualifying_\(round)"
        if !forceRefresh, let cached: [ChampionshipQualifyingResult] = loadCache(key: cacheKey) {
            self.qualifyingResults = cached
            return
        }
        guard let url = URL(string: "\(base)/\(season)/\(round)/qualifying.json") else {
            self.error = "Qualifying results: invalid URL for round \(round)"
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let mrData = json?["MRData"] as? [String: Any]
            let raceTable = mrData?["RaceTable"] as? [String: Any]
            let races = raceTable?["Races"] as? [[String: Any]]
            let resultsArray = races?.first?["QualifyingResults"] as? [[String: Any]] ?? []
            let results = try resultsArray.map { obj -> ChampionshipQualifyingResult in
                let itemData = try JSONSerialization.data(withJSONObject: obj)
                return try JSONDecoder().decode(ChampionshipQualifyingResult.self, from: itemData)
            }
            self.qualifyingResults = results
            saveCache(results, key: cacheKey)
            updateLastUpdated()
        } catch {
            self.error = "Qualifying results: \(error.localizedDescription)"
        }
    }
}
