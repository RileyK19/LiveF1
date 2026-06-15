//
//  F1TimingParser.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI

class F1TimingParser {
    static func parse(store: F1SessionStore) -> [Driver] {
        let debug_bool = false
        if debug_bool { print("🏎 DriverList: \(store.rawTopics["DriverList"] as? [String: Any] ?? [:])") }
        let driverList = store.rawTopics["DriverList"] as? [String: Any] ?? [:]
        let timingData = (store.rawTopics["TimingData"] as? [String: Any])?["Lines"] as? [String: Any] ?? [:]
        let appData = (store.rawTopics["TimingAppData"] as? [String: Any])?["Lines"] as? [String: Any] ?? [:]
        
        var drivers: [Driver] = []
        
        let timingStats = (store.rawTopics["TimingStats"] as? [String: Any])?["Lines"] as? [String: Any] ?? [:]
        
        for (number, driverRaw) in driverList {
            guard let d = driverRaw as? [String: Any] else { continue }
            let timing = timingData[number] as? [String: Any] ?? [:]
            if debug_bool { print("👤 \(number): tla=\(d["Tla"] ?? "nil") pos=\(timing["Position"] ?? "nil")") }
            let app = appData[number] as? [String: Any] ?? [:]
            if debug_bool { print("🏎 appData for \(number): \(app)") }
            
            if debug_bool { print("🔵 raw sectors for \(number): \(timing["Sectors"] ?? "nil")") }
            
            let s0 = parseSector(0, from: timing["Sectors"])
            let s1 = parseSector(1, from: timing["Sectors"])
            let s2 = parseSector(2, from: timing["Sectors"])
            
            let lastLapRaw = timing["LastLapTime"] as? [String: Any] ?? [:]
            let intervalRaw = timing["IntervalToPositionAhead"] as? [String: Any] ?? [:]
            
            // Latest stint for tyre info
            let stints = app["Stints"] as? [[String: Any]] ?? []
            let lastStint = stints.last ?? [:]
            
            let hexColour = d["TeamColour"] as? String ?? "FFFFFF"
            
            let bestLapRaw = timing["BestLapTime"] as? [String: Any] ?? [:]
            
            let driverStats = timingStats[number] as? [String: Any] ?? [:]
            let bestSectorsRaw = driverStats["BestSectors"] as? [[String: Any]] ?? []
            let bestS1 = bestSectorsRaw.count > 0 ? bestSectorsRaw[0]["Value"] as? String ?? "" : ""
            let bestS2 = bestSectorsRaw.count > 1 ? bestSectorsRaw[1]["Value"] as? String ?? "" : ""
            let bestS3 = bestSectorsRaw.count > 2 ? bestSectorsRaw[2]["Value"] as? String ?? "" : ""
            
            let curS1 = parseSector(0, from: timing["Sectors"])
            let curS2 = parseSector(1, from: timing["Sectors"])
            let curS3 = parseSector(2, from: timing["Sectors"])
            
            if debug_bool { print("🔢 delta for \(number): curS1=\(curS1) curS2=\(curS2) curS3=\(curS3) bestS1=\(bestS1) bestS2=\(bestS2) bestS3=\(bestS3)") }
            
            let sectorDelta: String = {
                guard !curS1.isEmpty || !curS2.isEmpty else { return "" }
                let hasSectors = !curS1.isEmpty || !curS2.isEmpty || !curS3.isEmpty
                guard hasSectors else { return "" }
                var cur = 0.0, best = 0.0
                if !curS1.isEmpty && !bestS1.isEmpty { cur += toSeconds(curS1); best += toSeconds(bestS1) }
                if !curS2.isEmpty && !bestS2.isEmpty { cur += toSeconds(curS2); best += toSeconds(bestS2) }
                if !curS3.isEmpty && !bestS3.isEmpty { cur += toSeconds(curS3); best += toSeconds(bestS3) }
                guard best > 0 else { return "" }
                let d = cur - best
                return (d < 0 ? "" : "+") + String(format: "%.3f", d)
            }()
            if debug_bool { print("🟢 \(number) PersonalFastest raw=\(lastLapRaw["PersonalFastest"] ?? "nil")") }
            
            drivers.append(Driver(
                id: number,
                position: Int(timing["Position"] as? String ?? "99") ?? 99,
                tla: d["Tla"] as? String ?? "???",
                fullName: d["FullName"] as? String ?? "",
                teamName: d["TeamName"] as? String ?? "",
                teamColour: Color(hex: hexColour),
                gap: timing["GapToLeader"] as? String ?? "",
                interval: intervalRaw["Value"] as? String ?? "",
                lastLap: lastLapRaw["Value"] as? String ?? "",
                isPersonalBest: (lastLapRaw["PersonalFastest"] as? Bool) ?? ((lastLapRaw["PersonalFastest"] as? Int) == 1),
                sector1: s0,
                sector2: s1,
                sector3: s2,
                compound: lastStint["Compound"] as? String ?? "",
                tyreAge: lastStint["TotalLaps"] as? Int ?? 0,
                pits: timing["NumberOfPitStops"] as? Int ?? 0,
                inPit: timing["InPit"] as? Bool ?? false,
                bestLap: bestLapRaw["Value"] as? String ?? "",
                isBestLap: (bestLapRaw["OverallFastest"] as? Bool) ?? ((bestLapRaw["OverallFastest"] as? Int) == 1),
                segments: F1TimingParser.parseSegments(timing["Sectors"]),
                sectorDelta: sectorDelta
            ))
        }
        
        return drivers.sorted { $0.position < $1.position }
    }
    
    private static func parseSector(_ index: Int, from sectors: Any?) -> String {
        if let arr = sectors as? [[String: Any]], index < arr.count {
            return extractSectorValue(arr[index])
        }
        if let dict = sectors as? [String: Any],
           let entry = dict["\(index)"] as? [String: Any] {
            return extractSectorValue(entry)
        }
        return ""
    }
    
    static func parseSegments(_ sectors: Any?) -> [[Int]] {
        var result: [[Int]] = [[], [], []]
        
        func extractSegments(_ sector: [String: Any], index: Int) {
            guard index < 3 else { return }
            if let segs = sector["Segments"] as? [[String: Any]] {
                result[index] = segs.compactMap { $0["Status"] as? Int }
            }
        }
        
        if let arr = sectors as? [[String: Any]] {
            for (i, sector) in arr.enumerated() { extractSegments(sector, index: i) }
        } else if let dict = sectors as? [String: Any] {
            for i in 0..<3 {
                if let sector = dict["\(i)"] as? [String: Any] { extractSegments(sector, index: i) }
            }
        }
        return result
    }
    
    private static func extractSectorValue(_ d: [String: Any]) -> String {
        let value = d["Value"] as? String ?? ""
        let previous = d["PreviousValue"] as? String ?? ""
        let stopped = (d["Stopped"] as? Bool) ?? ((d["Stopped"] as? Int) == 1)
        guard !stopped else { return "" }
        return value.isEmpty ? previous : value
    }
}

private func toSeconds(_ str: String) -> Double {
    let parts = str.split(separator: ":").map(String.init)
    if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) { return m * 60 + s }
    return Double(str) ?? 0
}
