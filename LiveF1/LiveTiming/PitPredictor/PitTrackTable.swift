//
//  PitTrackTable.swift
//  LiveF1
//
//  Loads artifacts/track_table.json (bundle it in the app target) and ports
//  strategy_features() from lib/track_stats.py.
//

import Foundation

struct TrackEntry: Decodable {
    let pitLoss: Double
    let pStops: [String: Double]                       // "1","2","3" -> share
    let stopWindows: [String: [String: [Double]]]      // strat -> stop# -> [lo, mid, hi] as fraction of race
    let stintLen: [String: [Double]]?
    let deg: [String: Double]?
    let racePace: Double?
    let pitPace: [String: [Double]]?
    let nRaces: Int?

    enum CodingKeys: String, CodingKey {
        case pitLoss = "pit_loss", pStops = "p_stops", stopWindows = "stop_windows"
        case stintLen = "stint_len", deg, racePace = "race_pace", pitPace = "pit_pace", nRaces = "n_races"
    }
}

struct PitTrackTable {
    let entries: [String: TrackEntry]

    static func load() -> PitTrackTable? {
        guard let url = Bundle.main.url(forResource: "track_table", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([String: TrackEntry].self, from: data),
              entries["_global"] != nil
        else { print("❌ track_table.json missing or unreadable"); return nil }
        return PitTrackTable(entries: entries)
    }

    /// Mirrors resolve(): falls back to _global. `usedFallback` lets you see
    /// when the feed's location string doesn't match a table key.
    func resolve(_ track: String) -> (entry: TrackEntry, usedFallback: Bool) {
        if let e = entries[track] { return (e, false) }
        return (entries["_global"]!, true)
    }
}

// Assumes STRATS = (1, 2, 3) and config.KMAX = 3. Check against lib/track_stats.py.
private let strats = [1, 2, 3]
private let kMax = 3

/// Same maths as strategy_features(). stopsDone = stint number - 1.
func strategyFeatures(entry: TrackEntry, stopsDone s: Int, lap: Double, totalLaps: Int) -> [String: Double] {
    let p: [Int: Double] = Dictionary(uniqueKeysWithValues: strats.map { ($0, entry.pStops[String($0)] ?? 0) })
    let typical = strats.reduce(0.0) { $0 + Double($1) * (p[$1] ?? 0) }
    let total = Double(totalLaps)

    var pMore = 0.0
    var win = [total, total, total]   // lo, mid, hi (laps)

    if s >= 0 && s < kMax {
        let more = strats.filter { $0 > s }
        let wMore = more.reduce(0.0) { $0 + (p[$1] ?? 0) }
        if wMore > 0 {
            let wAll = strats.filter { $0 >= max(s, 1) }.reduce(0.0) { $0 + (p[$1] ?? 0) }
            pMore = wMore / wAll
            for i in 0..<3 {
                var frac = 0.0
                for k in more {
                    guard let w = entry.stopWindows[String(k)]?[String(s + 1)], w.count == 3 else { continue }
                    frac += (p[k] ?? 0) / wMore * w[i]
                }
                win[i] = frac * total
            }
        }
    }
    return [
        "typical_stops": typical,
        "p_more_stops": pMore,
        "lap_over_window_lo": lap - win[0],
        "window_hi_over_lap": win[2] - lap,
        "laps_to_window_mid": win[1] - lap,
    ]
}