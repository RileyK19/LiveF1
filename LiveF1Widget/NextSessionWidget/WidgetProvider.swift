//
//  WidgetProvider.swift
//  LiveF1
//
//  Created by Riley Koo on 7/3/26.
//

import WidgetKit
import SwiftUI

struct NextSessionEntry: TimelineEntry {
    let date: Date
    let race: ChampionshipRace?
    let sessionName: String?
    let session: ChampionshipSession?
}

struct NextSessionProvider: TimelineProvider {

    private let defaults = UserDefaults(suiteName: "group.com.riley.livef1")

    func placeholder(in context: Context) -> NextSessionEntry {
        NextSessionEntry(date: .now, race: nil, sessionName: nil, session: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextSessionEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextSessionEntry>) -> Void) {
        let entry = loadEntry()

        // Refresh again either at the next session's start time, or in 6h if nothing's found —
        // whichever comes first. This keeps the widget accurate without polling constantly.
        let nextRefresh = entry.session?.dateTime ?? Date().addingTimeInterval(6 * 3600)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func loadEntry() -> NextSessionEntry {
        guard let data = defaults?.data(forKey: "f1_cache_schedule"),
              let cacheEntry = try? JSONDecoder().decode(ChampionshipCacheEntry<[ChampionshipRace]>.self, from: data)
        else {
            return NextSessionEntry(date: .now, race: nil, sessionName: nil, session: nil)
        }

        let races = cacheEntry.data
        let now = Date()

        // Flatten all sessions across all races, find the soonest one that hasn't started yet
        let upcoming = races
            .flatMap { race in race.allSessions.map { (race, $0.name, $0.session) } }
            .filter { (_, _, s) in
                if let dt = s.dateTime { return dt > now }
                return false
            }
            .sorted { (a, b) in
                (a.2.dateTime ?? .distantFuture) < (b.2.dateTime ?? .distantFuture)
            }

        guard let (race, name, session) = upcoming.first else {
            return NextSessionEntry(date: now, race: nil, sessionName: nil, session: nil)
        }

        return NextSessionEntry(date: now, race: race, sessionName: name, session: session)
    }
}
