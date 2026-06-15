//
//  F1ReplayClient.swift
//  LiveF1
//
//  Created by Riley Koo on 6/4/26.
//


import Foundation
import Compression

// Replays a past F1 session from F1's static file hosting.
// URL pattern: https://livetiming.formula1.com/static/{year}/{meeting}/{session}/{Topic}.jsonStream
//
// Each line in a .jsonStream file looks like:
//   "0:12:34.567"{"Lines":{"1":{"GapToLeader":"0.342"}}}
// — a quoted timestamp, then the raw JSON delta.
// We parse the timestamp, work out the real delay between messages, and replay at original speed
// (or faster with the `speed` multiplier).

class F1ReplayClient: F1DataSource {
    var onMessage: ((String, [String: Any]) -> Void)?
    var onStateChange: ((DataSourceState) -> Void)?

    private var replayTask: Task<Void, Never>?

    // Speed multiplier — 1.0 = real time, 10.0 = 10x faster
    var speed: Double = 10.0

    // Topics to replay. Matches what the live client subscribes to.
    private let topics = [
        "TimingData", "TimingAppData", "DriverList", "WeatherData",
        "TrackStatus", "RaceControlMessages", "SessionInfo", "LapCount",
        "CarData.z", "Position.z"
    ]

    // sessionPath e.g. "2025/2025-05-25_Monaco_Grand_Prix/2025-05-25_Race"
    func start(sessionPath: String) {
        onStateChange?(.connecting)
        replayTask = Task {
            await runReplay(sessionPath: sessionPath)
        }
    }

    func stop() {
        replayTask?.cancel()
        onStateChange?(.disconnected)
    }

    private func runReplay(sessionPath: String) async {
        let base = "https://livetiming.formula1.com/static/\(sessionPath)"

        // Only load static keyframes that don't change during session
        let staticTopics = ["DriverList", "SessionInfo"]
        for topic in staticTopics {
            guard !Task.isCancelled else { return }
            if let keyframe = await fetchJSON("\(base)/\(topic).json") {
                onMessage?(topic, keyframe)
            }
        }

        onStateChange?(.connected)

        var allLines: [(TimeInterval, String, [String: Any])] = []
        let streamTopics = ["TimingData", "TimingAppData", "TrackStatus", "RaceControlMessages", "LapCount", "WeatherData"]

        for topic in streamTopics {
            guard !Task.isCancelled else { return }
            if let stream = await fetchText("\(base)/\(topic).jsonStream") {
                let firstLine = stream.components(separatedBy: "\n").first(where: { !$0.isEmpty }) ?? "empty"
                print("📄 first line of \(topic): \(firstLine.prefix(100))")

                for line in stream.components(separatedBy: "\n") {
                    if let (ts, payload) = parseLine(line) {
                        allLines.append((ts, topic, payload))
                    }
                }
            } else {
                print("❌ failed to fetch \(topic)")
            }
        }

        allLines.sort { $0.0 < $1.0 }
        print("▶ replaying \(allLines.count) lines from \(streamTopics.count) topics")

        var lastTimestamp: TimeInterval = 0
        for (timestamp, topic, payload) in allLines {
            guard !Task.isCancelled else { return }
            let gap = lastTimestamp == 0 ? 0 : (timestamp - lastTimestamp) / speed
            if gap > 0 {
                try? await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))
            }
            lastTimestamp = timestamp
            onMessage?(topic, payload)
        }
    }

    private func replayStream(lines: [String], topic: String) async {
        var lastTimestamp: TimeInterval = 0

        for line in lines {
            guard !Task.isCancelled else { return }
            guard !line.isEmpty else { continue }

            guard let (timestamp, payload) = parseLine(line) else { continue }

            // Delay between this message and the last, scaled by speed
            let gap = lastTimestamp == 0 ? 0 : (timestamp - lastTimestamp) / speed
            if gap > 0 {
                try? await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))
            }
            lastTimestamp = timestamp

            onMessage?(topic, payload)
        }
    }

    private func parseLine(_ line: String) -> (TimeInterval, [String: Any])? {
        guard !line.isEmpty else { return nil }
        
        // Format: 00:00:04.219{...json...}  (no quotes around timestamp)
        // Find the first { which marks start of JSON
        guard let jsonStart = line.firstIndex(of: "{") else { return nil }
        
        let timestampStr = String(line[line.startIndex..<jsonStart])
        let jsonStr = String(line[jsonStart...])
        
        guard let ts = parseTimestamp(timestampStr.trimmingCharacters(in: .whitespaces)),
              let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        
        return (ts, json)
    }

    // "H:MM:SS.mmm" → TimeInterval in seconds
    private func parseTimestamp(_ s: String) -> TimeInterval? {
        let parts = s.split(separator: ":").map(String.init)
        guard parts.count == 3,
              let h = Double(parts[0]),
              let m = Double(parts[1]),
              let sec = Double(parts[2])
        else { return nil }
        return h * 3600 + m * 60 + sec
    }

    private func fetchJSON(_ urlString: String) async -> [String: Any]? {
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    private func fetchText(_ urlString: String) async -> String? {
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url)
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Session discovery

struct F1Session: Identifiable {
    let id: String  // the path segment e.g. "2025-05-25_Race"
    let path: String
    let name: String
}

// Fetch available sessions for a year from F1's static index
func fetchSessions(year: Int) async -> [F1Session] {
    let url = "https://livetiming.formula1.com/static/\(year)/Index.json"
    guard let urlObj = URL(string: url),
          let (data, _) = try? await URLSession.shared.data(from: urlObj),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let meetings = json["Meetings"] as? [[String: Any]]
    else { return [] }

    var sessions: [F1Session] = []
    for meeting in meetings {
        guard let meetingSessions = meeting["Sessions"] as? [[String: Any]] else { continue }
        let meetingName = (meeting["Name"] as? String) ?? (meeting["OfficialName"] as? String) ?? "Unknown"
        for session in meetingSessions {
            guard let sessionPath = session["Path"] as? String,
                  let sessionName = session["Name"] as? String
            else { continue }
            let fullPath = sessionPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            sessions.append(F1Session(id: fullPath, path: fullPath, name: "\(meetingName) — \(sessionName)"))
        }
    }
    return sessions
}
