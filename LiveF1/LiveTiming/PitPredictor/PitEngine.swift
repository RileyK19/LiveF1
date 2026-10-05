//
//  PitEngine.swift
//  LiveF1
//
//  Reads F1SessionStore.rawTopics, detects each driver's lap completion,
//  builds the feature vector and runs the models.
//

import Foundation

struct PitPrediction: Equatable {
    let lap: Int            // laps completed when predicted
    let pWillStop: Double
    let pWithin5: Double
    let lapsLow: Double     // laps from now, sorted so low <= median <= high
    let lapsMedian: Double
    let lapsHigh: Double
}

/// Everything parsed for one driver at one lap tick.
struct PitContext {
    var driver: String
    var lap: Int                    // laps completed (NumberOfLaps)
    var totalLaps: Int
    var stintNumber: Int            // highest stint key + 1
    var stopsDone: Int { stintNumber - 1 }
    var tyreAge: Int                // TotalLaps of the current stint
    var compound: String
    var compoundsUsed: Set<String>  // only trustworthy if the snapshot includes earlier stints
    var lastLap: Double
    var bestLap: Double?
    var position: Int
    var gapToLeader: Double
    var gapAhead: Double?
    var gapBehind: Double?
    var rejoinPosition: Int
    var positionsLost: Int
    var rejoinGapAhead: Double?
    var rejoinGapBehind: Double?
    var trackStatus: String
    var airTemp: Double?
    var trackTemp: Double?
    var humidity: Double?
    var windSpeed: Double?
    var raining: Bool
    var fieldMedianLap: Double?
    var aheadTyreAge: Int?
    var behindTyreAge: Int?
}

@MainActor
final class PitEngine {
    private let models = PitModels()
    private let table = PitTrackTable.load()

    private var lastLaps: [String: Int] = [:]
    private var lastStintCount: [String: Int] = [:]
    private var prevTickWasPit: [String: Bool] = [:]
    private var warnedFallbackFor: String?

    private(set) var predictions: [String: PitPrediction] = [:]

    /// Call after every merged TimingData / TimingAppData message. Returns true if predictions changed.
    @discardableResult
    func update(_ topics: [String: Any]) -> Bool {
        guard let models, let table else {
            print("⚠️ PitEngine: models or table failed to load")
            return false
        }
        guard let timing = (topics["TimingData"] as? [String: Any])?["Lines"] as? [String: Any] else { return false }

        let appLines = (topics["TimingAppData"] as? [String: Any])?["Lines"] as? [String: Any] ?? [:]
        let status = (topics["TrackStatus"] as? [String: Any])?["Status"].map { "\($0)" } ?? "1"
        let totalLaps = Int(num((topics["LapCount"] as? [String: Any])?["TotalLaps"]) ?? 0)
        let location = ((topics["SessionInfo"] as? [String: Any])?["Meeting"] as? [String: Any])?["Location"] as? String ?? ""
        // same slug rule as config.track_key() in Python
        let slug = location.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let weather = topics["WeatherData"] as? [String: Any]

        let (entry, usedFallback) = table.resolve(slug)
        if usedFallback, warnedFallbackFor != slug {
            warnedFallbackFor = slug
            print("⚠️ track '\(slug)' not in track_table, using _global")
        }

        // Gap to leader per car, in seconds.
        struct Car { let number: String; let pos: Int; var gap: Double }
        var cars: [Car] = []
        for (number, rawLine) in timing {
            guard let line = rawLine as? [String: Any],
                  let pos = num(line["Position"]).map({ Int($0) }), pos > 0,
                  !flag(line["Retired"]), !flag(line["Stopped"]) else { continue }
            if pos == 1 { cars.append(Car(number: number, pos: pos, gap: 0)); continue }
            let ref = parseLap((line["LastLapTime"] as? [String: Any])?["Value"]) ?? 90
            switch parseGap(line["GapToLeader"]) {
            case .seconds(let s): cars.append(Car(number: number, pos: pos, gap: s))
            case .laps(let n): cars.append(Car(number: number, pos: pos, gap: Double(n) * ref))
            case .none: continue
            }
        }
        cars.sort { $0.pos < $1.pos }

        let fieldMedianLap = median(timing.values.compactMap {
            parseLap((($0 as? [String: Any])?["LastLapTime"] as? [String: Any])?["Value"])
        })

        var changed = false

        for (number, rawLine) in timing {
            guard let line = rawLine as? [String: Any],
                  let laps = num(line["NumberOfLaps"]).map({ Int($0) }) else { continue }
            guard let prev = lastLaps[number] else { lastLaps[number] = laps; continue }   // first sight: just remember
            guard laps > prev else { if laps < prev { lastLaps[number] = laps }; continue }
            lastLaps[number] = laps

            // ---- lap tick: gather what we need
            let stints = children(((appLines[number] as? [String: Any])?["Stints"]))
            let stintCount = (stints.map { $0.0 }.max() ?? -1) + 1
            let stintChanged = lastStintCount[number].map { $0 != stintCount } ?? false
            lastStintCount[number] = stintCount

            let inPit = flag(line["InPit"]) || flag(line["PitOut"])
            let wasPitRelated = prevTickWasPit[number] ?? false
            prevTickWasPit[number] = inPit || stintChanged

            let lastLapOpt = parseLap((line["LastLapTime"] as? [String: Any])?["Value"])
            let blockedStatus = ["4", "5", "6", "7"].contains(status)   // SC, red, VSC deployed/ending
            let retired = flag(line["Retired"]) || flag(line["Stopped"])

            guard laps > 1, laps < totalLaps, !blockedStatus, !retired, !inPit, !stintChanged, !wasPitRelated,
                  let lastLap = lastLapOpt, let curStint = stints.last?.1,
                  let me = cars.first(where: { $0.number == number })
            else {
                print("⏭️ #\(number) L\(laps): " + [
                    laps <= 1 ? "lap1" : nil,
                    laps >= totalLaps ? "totalLaps=\(totalLaps)" : nil,
                    blockedStatus ? "status \(status)" : nil,
                    retired ? "retired/stopped" : nil,
                    inPit ? "inPit/pitOut" : nil,
                    stintChanged ? "stint changed" : nil,
                    wasPitRelated ? "lap after pit" : nil,
                    lastLapOpt == nil ? "no lastLap" : nil,
                    stints.last == nil ? "no stint" : nil,
                    cars.contains(where: { $0.number == number }) ? nil : "not in cars (position/gap)"
                ].compactMap { $0 }.joined(separator: ", "))
                if predictions.removeValue(forKey: number) != nil { changed = true }
                continue
            }

            // ---- neighbours and rejoin
            let idx = cars.firstIndex(where: { $0.number == number })!
            let gapAhead = idx > 0 ? me.gap - cars[idx - 1].gap : nil
            let gapBehind = idx + 1 < cars.count ? cars[idx + 1].gap - me.gap : nil
            let rejoin = me.gap + entry.pitLoss
            let others = cars.filter { $0.number != number }
            let lost = others.filter { $0.gap > me.gap && $0.gap < rejoin }.count
            let aheadAfter = others.filter { $0.gap < rejoin }.map { $0.gap }.max()
            let behindAfter = others.filter { $0.gap > rejoin }.map { $0.gap }.min()

            let ctx = PitContext(
                driver: number, lap: laps, totalLaps: totalLaps,
                stintNumber: stintCount,
                tyreAge: Int(num(curStint["TotalLaps"]) ?? 0),
                compound: (curStint["Compound"] as? String ?? "UNKNOWN").uppercased(),
                compoundsUsed: Set(stints.compactMap { ($0.1["Compound"] as? String)?.uppercased() }),
                lastLap: lastLap,
                bestLap: parseLap((line["BestLapTime"] as? [String: Any])?["Value"]),
                position: me.pos, gapToLeader: me.gap, gapAhead: gapAhead, gapBehind: gapBehind,
                rejoinPosition: me.pos + lost, positionsLost: lost,
                rejoinGapAhead: aheadAfter.map { rejoin - $0 },
                rejoinGapBehind: behindAfter.map { $0 - rejoin },
                trackStatus: status,
                airTemp: num(weather?["AirTemp"]), trackTemp: num(weather?["TrackTemp"]),
                humidity: num(weather?["Humidity"]), windSpeed: num(weather?["WindSpeed"]),
                raining: (num(weather?["Rainfall"]) ?? 0) > 0,
                fieldMedianLap: fieldMedianLap,
                aheadTyreAge: idx > 0 ? tyreAge(of: cars[idx - 1].number, in: appLines) : nil,
                behindTyreAge: idx + 1 < cars.count ? tyreAge(of: cars[idx + 1].number, in: appLines) : nil
            )
            
            guard let f = features(for: ctx, entry: entry) else {
                print("⚠️ PitEngine: no features for \(number) compound=\(ctx.compound)")
                print("⏭️ #\(number) L\(laps): features nil (compound \(ctx.compound), totalLaps \(totalLaps))")
                continue
            }
            guard let out = models.predict(f) else {
                print("⚠️ PitEngine: predict returned nil for \(number)")
                continue
            }
            print("🛞 \(number) lap \(laps): stop=\(out.willStop) within5=\(out.within5)")

            let q = [out.lapsLow, out.lapsMedian, out.lapsHigh].sorted()
            predictions[number] = PitPrediction(
                lap: laps, pWillStop: out.willStop, pWithin5: out.within5,
                lapsLow: q[0], lapsMedian: q[1], lapsHigh: q[2])
            changed = true
        }
        return changed
    }

    // MARK: - Feature mapping

    private static let compoundCode: [String: Double] =
        ["SOFT": 0, "MEDIUM": 1, "HARD": 2, "INTERMEDIATE": 3, "WET": 4]

    /// Names and definitions must match config.FEATURES / lib/features.py.
    private func features(for c: PitContext, entry: TrackEntry) -> [String: Double]? {
        guard c.totalLaps > 0, let code = Self.compoundCode[c.compound],
              let q = entry.stintLen?[c.compound], q.count == 3 else { return nil }   // q = [p25, p50, p75]
        var f = strategyFeatures(entry: entry, stopsDone: c.stopsDone, lap: Double(c.lap), totalLaps: c.totalLaps)

        let age = Double(c.tyreAge)
        let left = Double(c.totalLaps - c.lap)
        let cap = 60.0
        func clip(_ x: Double?) -> Double { min(max(x ?? cap, 0), cap) }   // missing = clear air
        let best = min(c.bestLap ?? c.lastLap, c.lastLap)
        let expLeft = q[1] - age

        f["lap_number"] = Double(c.lap)
        f["laps_remaining"] = left
        f["race_progress"] = Double(c.lap) / Double(c.totalLaps)
        f["stint_number"] = Double(c.stintNumber)
        f["compound"] = code
        f["tyre_life"] = age
        f["typical_stint_len"] = q[1]
        f["stint_len_p25"] = q[0]
        f["stint_len_p75"] = q[2]
        f["tyre_life_over_typical"] = age - q[1]
        f["tyre_life_over_p25"] = age - q[0]
        f["tyre_life_over_p75"] = age - q[2]
        f["deg_rate"] = entry.deg?[c.compound] ?? 0
        f["last_lap_time"] = c.lastLap
        f["best_lap_time"] = best
        f["delta_to_best"] = c.lastLap - best
        f["delta_to_field"] = c.lastLap - (c.fieldMedianLap ?? c.lastLap)
        f["position"] = Double(c.position)
        f["gap_ahead"] = clip(c.gapAhead)
        f["gap_behind"] = clip(c.gapBehind)
        f["pit_loss"] = entry.pitLoss
        f["positions_lost_if_pit"] = Double(c.positionsLost)
        f["rejoin_gap_ahead"] = clip(c.rejoinGapAhead)
        f["rejoin_gap_behind"] = clip(c.rejoinGapBehind)
        // car ahead already finished this lap; car behind has not, so no -1 here
        f["tyre_age_diff_ahead"] = c.aheadTyreAge.map { Double($0) - age } ?? 0
        f["tyre_age_diff_behind"] = c.behindTyreAge.map { Double($0) - age } ?? 0
        f["expected_stint_left"] = expLeft
        f["finish_margin"] = left - expLeft
        f["n_compounds_used"] = Double(c.compoundsUsed.count)
        f["track_temp"] = c.trackTemp ?? 30
        f["rainfall"] = c.raining ? 1 : 0
        return f
    }

    private func tyreAge(of number: String, in appLines: [String: Any]) -> Int? {
        let stints = children((appLines[number] as? [String: Any])?["Stints"])
        return stints.last.flatMap { num($0.1["TotalLaps"]) }.map { Int($0) }
    }

    private func median(_ xs: [Double]) -> Double? {
        guard !xs.isEmpty else { return nil }
        let s = xs.sorted(), n = s.count
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }
}

// MARK: - Parsing helpers

private func num(_ v: Any?) -> Double? {
    if let d = v as? Double { return d }
    if let i = v as? Int { return Double(i) }
    if let s = v as? String { return Double(s.trimmingCharacters(in: .whitespaces)) }
    return nil
}

private func flag(_ v: Any?) -> Bool {
    if let b = v as? Bool { return b }
    if let s = v as? String { return s.lowercased() == "true" || s == "1" }
    if let i = v as? Int { return i != 0 }
    return false
}

/// Lists and dicts alike (index -> string key), sorted by index.
private func children(_ v: Any?) -> [(Int, [String: Any])] {
    if let arr = v as? [Any] {
        return arr.enumerated().compactMap { i, e in (e as? [String: Any]).map { (i, $0) } }
    }
    if let d = v as? [String: Any] {
        return d.compactMap { k, e -> (Int, [String: Any])? in
            guard let i = Int(k), let m = e as? [String: Any] else { return nil }
            return (i, m)
        }.sorted { $0.0 < $1.0 }
    }
    return []
}

/// "1:31.298" or "31.298" -> seconds
private func parseLap(_ v: Any?) -> Double? {
    guard let s = (v as? String)?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
    let parts = s.split(separator: ":")
    if parts.count == 2, let m = Double(parts[0]), let sec = Double(parts[1]) { return m * 60 + sec }
    if parts.count == 1 { return Double(parts[0]) }
    return nil
}

private enum Gap { case seconds(Double), laps(Int), none }

/// "+1.234", "1 LAP", "2 LAPS", "" (leader / missing)
private func parseGap(_ v: Any?) -> Gap {
    if let d = v as? Double { return .seconds(d) }
    guard let s = (v as? String)?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return .none }
    if s.uppercased().contains("LAP") {
        let digits = s.filter { $0.isNumber }
        return Int(digits).map { .laps($0) } ?? .none
    }
    return Double(s.replacingOccurrences(of: "+", with: "")).map { .seconds($0) } ?? .none
}
