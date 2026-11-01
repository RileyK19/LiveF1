//
//  F1ReplayClient.swift
//  LiveF1
//
//  Created by Riley Koo on 6/4/26.
//


//  Layout of the pieces:
//    F1ZDecoder     – shared base64 + deflate + JSON decoding for ".z" topics
//    ReplayCache    – single-slot in-memory cache: holds the raw files for ONE session,
//                     replaced when a different session is requested
//    ReplayLoader   – fetches (via the cache) and indexes the files into a sorted event list
//    F1ReplayClient – plays the events out through onMessage (paced or unpaced)
//
//  Each line in a .jsonStream file looks like one of:
//    00:00:04.219{"Lines":{"1":{"GapToLeader":"0.342"}}}     (plain JSON delta)
//    00:01:02.345"eJzt..."                                   (".z" topics: quoted base64 of deflated JSON)
//

import Foundation

// MARK: - Shared ".z" decoding

enum F1ZDecoder {
    /// base64 text (as bytes) -> inflate -> JSON object
    static func decode(base64: Data) -> [String: Any]? {
        guard let compressed = Data(base64Encoded: base64) else { return nil }

        // Some payloads carry a 2-byte zlib header (0x78 ..); Apple's .zlib expects raw deflate.
        let payload: Data
        if compressed.count > 2, compressed[compressed.startIndex] == 0x78 {
            payload = Data(compressed.dropFirst(2))
        } else {
            payload = compressed
        }

        guard let inflated = try? (payload as NSData).decompressed(using: .zlib) else { return nil }
        return try? JSONSerialization.jsonObject(with: inflated as Data) as? [String: Any]
    }
}

// MARK: - Events

/// One replayable message. `body` is a slice of the cached file, so nothing is
/// parsed or decompressed until `payload()` is called at playback time.
struct ReplayEvent: Sendable {
    let offset: TimeInterval   // seconds since session stream start
    let topicOrder: Int        // tie-breakers so equal timestamps keep a stable order
    let lineIndex: Int
    let topic: String
    let body: Data
    let isCompressed: Bool

    func payload() -> [String: Any]? {
        if isCompressed {
            return F1ZDecoder.decode(base64: Data(body))
        }
        return try? JSONSerialization.jsonObject(with: Data(body)) as? [String: Any]
    }
}

struct LoadedReplay: Sendable {
    let sessionPath: String
    let keyframes: [(topic: String, body: Data)]   // DriverList / SessionInfo snapshots
    let events: [ReplayEvent]                      // sorted by time
}

// MARK: - Single-slot cache

/// Holds the raw downloaded files for one session. Asking for a different session
/// drops the old one. In memory only, so it is gone after the app relaunches;
/// swapping this for a disk-backed store later only touches this actor.
actor ReplayCache {
    static let shared = ReplayCache()

    private var sessionPath: String?
    private var files: [String: Data] = [:]   // file name -> raw bytes

    func data(for sessionPath: String, names: [String]) async -> [String: Data] {
        if self.sessionPath != sessionPath {
            self.sessionPath = sessionPath
            files = [:]
        }

        let missing = names.filter { files[$0] == nil }
        var fetched: [String: Data] = [:]

        if !missing.isEmpty {
            let base = "https://livetiming.formula1.com/static/\(sessionPath)"
            fetched = await withTaskGroup(of: (String, Data?).self) { group in
                for name in missing {
                    group.addTask { (name, await ReplayCache.fetch("\(base)/\(name)")) }
                }
                var out: [String: Data] = [:]
                for await (name, data) in group {
                    if let data { out[name] = data }
                }
                return out
            }
            // Actor reentrancy: a different session may have been requested while we awaited.
            if self.sessionPath == sessionPath {
                files.merge(fetched) { _, new in new }
            }
        }

        var result: [String: Data] = [:]
        for name in names {
            if let d = files[name] ?? fetched[name] { result[name] = d }
        }
        return result
    }

    func clear() {
        sessionPath = nil
        files = [:]
    }

    private static func fetch(_ urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        if let token = TokenStore.load() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code == 200 else {
            print("⚠️ replay fetch \(code): \(url.lastPathComponent)")
            return nil
        }
        return data
    }
}

// MARK: - Loader

enum ReplayLoader {
    static let keyframeTopics = ["DriverList", "SessionInfo"]
    static let streamTopics = [
//        "TimingData", "TimingAppData", "TimingStats", "TrackStatus",
//        "RaceControlMessages", "LapCount", "WeatherData", "SessionData",
//        "TeamRadio", "CarData.z", "Position.z"
        "Heartbeat", "CarData.z", "Position.z", "ExtrapolatedClock",
        "TopThree", "TimingStats", "TimingAppData", "WeatherData",
        "TrackStatus", "DriverList", "RaceControlMessages",
        "SessionInfo", "SessionData", "LapCount", "TimingData", "TeamRadio",
        "SessionStatus"
    ]

    static func normalize(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func load(sessionPath rawPath: String) async -> LoadedReplay {
        let sessionPath = normalize(rawPath)
        let keyNames = keyframeTopics.map { "\($0).json" }
        let streamNames = streamTopics.map { "\($0).jsonStream" }

        let files = await ReplayCache.shared.data(for: sessionPath, names: keyNames + streamNames)

        // Index off the calling thread.
        let events = await Task.detached(priority: .userInitiated) { () -> [ReplayEvent] in
            var all: [ReplayEvent] = []
            for (order, topic) in streamTopics.enumerated() {
                guard let data = files["\(topic).jsonStream"] else {
                    print("⚠️ replay: no data for \(topic) (missing or not accessible)")
                    continue
                }
                all += index(data: data, topic: topic, topicOrder: order)
            }
            all.sort {
                if $0.offset != $1.offset { return $0.offset < $1.offset }
                if $0.topicOrder != $1.topicOrder { return $0.topicOrder < $1.topicOrder }
                return $0.lineIndex < $1.lineIndex
            }
            return all
        }.value

        var keyframes: [(topic: String, body: Data)] = []
        for topic in keyframeTopics {
            if let data = files["\(topic).json"] {
                keyframes.append((topic, stripBOM(data)))
            } else {
                print("⚠️ replay: no keyframe for \(topic)")
            }
        }

        print("▶ replay loaded: \(events.count) events from \(sessionPath)")
        return LoadedReplay(sessionPath: sessionPath, keyframes: keyframes, events: events)
    }

    static func stripBOM(_ data: Data) -> Data {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { return Data(data.dropFirst(3)) }
        return data
    }

    /// Walks the file's bytes once, recording each line's timestamp and body slice.
    /// Nothing is copied or JSON-parsed here.
    static func index(data: Data, topic: String, topicOrder: Int) -> [ReplayEvent] {
        var events: [ReplayEvent] = []
        let newline: UInt8 = 0x0A, cr: UInt8 = 0x0D, brace: UInt8 = 0x7B, quote: UInt8 = 0x22
        let base = data.startIndex

        data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
            let n = buf.count
            var lineStart = 0
            var lineIndex = 0

            while lineStart < n {
                var lineEnd = lineStart
                while lineEnd < n && buf[lineEnd] != newline { lineEnd += 1 }
                defer { lineStart = lineEnd + 1; lineIndex += 1 }

                var end = lineEnd
                if end > lineStart && buf[end - 1] == cr { end -= 1 }

                // First '{' or '"' marks where the payload starts; everything before is the timestamp.
                var marker = lineStart
                while marker < end && buf[marker] != brace && buf[marker] != quote { marker += 1 }
                guard marker < end else { continue }

                let tsString = String(decoding: UnsafeRawBufferPointer(rebasing: buf[lineStart..<marker]), as: UTF8.self)
                guard let offset = parseTimestamp(tsString) else { continue }

                if buf[marker] == quote {
                    // ".z" line: body is the text between the first and last quote.
                    var closing = end - 1
                    while closing > marker && buf[closing] != quote { closing -= 1 }
                    guard closing > marker + 1 else { continue }
                    events.append(ReplayEvent(offset: offset, topicOrder: topicOrder, lineIndex: lineIndex, topic: topic,
                                              body: data[(base + marker + 1)..<(base + closing)], isCompressed: true))
                } else {
                    events.append(ReplayEvent(offset: offset, topicOrder: topicOrder, lineIndex: lineIndex, topic: topic,
                                              body: data[(base + marker)..<(base + end)], isCompressed: false))
                }
            }
        }
        return events
    }

    // "H:MM:SS.mmm" -> seconds
    static func parseTimestamp(_ raw: String) -> TimeInterval? {
        var strip = CharacterSet.whitespacesAndNewlines
        strip.insert(charactersIn: "\u{FEFF}")
        let parts = raw.trimmingCharacters(in: strip).split(separator: ":")
        guard parts.count == 3,
              let h = Double(parts[0]),
              let m = Double(parts[1]),
              let s = Double(parts[2])
        else { return nil }
        return h * 3600 + m * 60 + s
    }
}

// MARK: - Client

enum ReplayPacing {
    case realtime(speed: Double)   // 1.0 = real time, 10.0 = 10x
    case unpaced                   // as fast as the consumer accepts (benchmarks)
}

actor F1ReplayClient: F1DataSource {
//    var onMessage: ((String, [String: Any]) -> Void)?
//    var onStateChange: ((DataSourceState) -> Void)?
    
    let (stream, continuation) = AsyncStream.makeStream(of: F1LiveEvent.self, bufferingPolicy: .bufferingOldest(1000))

    var pacing: ReplayPacing = .realtime(speed: 10)

    private var replayTask: Task<Void, Never>?
    private var loaded: LoadedReplay?

    /// Download (or reuse the cached copy of) a session and index it, without playing it.
    /// Call this first when benchmarking so load cost isn't mixed into pipeline timings.
    @discardableResult
    func preload(sessionPath: String) async -> Int {
//        onStateChange?(.connecting)
        continuation.yield(.state(.connecting))
        let result = await ReplayLoader.load(sessionPath: sessionPath)
        loaded = result
        return result.events.count
    }

    // sessionPath e.g. "2025/2025-05-25_Monaco_Grand_Prix/2025-05-25_Race"
    func start(sessionPath: String) {
        replayTask?.cancel()
        replayTask = Task { [weak self] in
            await self?.runReplay(sessionPath: sessionPath)
        }
    }

    func stop() {
        replayTask?.cancel()
        replayTask = nil
//        onStateChange?(.disconnected)
        continuation.yield(.state(.disconnected))
    }

    private func runReplay(sessionPath: String) async {
//        onStateChange?(.connecting)
        continuation.yield(.state(.connecting))

        let normalized = ReplayLoader.normalize(sessionPath)
        let replay: LoadedReplay
        if let loaded, loaded.sessionPath == normalized {
            replay = loaded
        } else {
            replay = await ReplayLoader.load(sessionPath: normalized)
            loaded = replay
        }
        guard !Task.isCancelled else { return }

        // Static snapshots first so the store has the driver list and session path.
        for frame in replay.keyframes {
            if let json = try? JSONSerialization.jsonObject(with: frame.body) as? [String: Any] {
                //                onMessage?(frame.topic, json)
                guard await send(.message(topic: frame.topic, payload: json)) else { return }
            }
        }
//        onStateChange?(.connected)
        continuation.yield(.state(.connected))

        guard let first = replay.events.first else { return }

        let clock = ContinuousClock()
        let start = clock.now

        for (i, event) in replay.events.enumerated() {
            if Task.isCancelled { return }

            switch pacing {
            case .realtime(let speed) where speed > 0:
                // Sleep until an absolute deadline so per-message errors never accumulate.
                let deadline = start.advanced(by: .seconds((event.offset - first.offset) / speed))
                if clock.now < deadline {
                    do { try await clock.sleep(until: deadline) } catch { return }
                }
            default:
                if i % 200 == 0 { await Task.yield() }
            }

            guard let payload = event.payload() else { continue }
//            onMessage?(event.topic, payload)
            guard await send(.message(topic: event.topic, payload: payload)) else { return }
        }
        
        continuation.yield(.state(.disconnected))
    }
    
    private func send(_ event: F1LiveEvent) async -> Bool {
        while true {
            switch continuation.yield(event) {
            case .enqueued: return true
            case .terminated: return false
            case .dropped:
                do { try await Task.sleep(for: .milliseconds(2)) }
                catch { return false }
            @unknown default: return false
            }
        }
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
    guard let urlObj = URL(string: url) else { return [] }
    let rawData: Data
    do {
        var request = URLRequest(url: urlObj)
        if let token = TokenStore.load() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("🔍 \(year) Index.json → HTTP \(code), \(data.count) bytes, token: \(TokenStore.load() != nil)")
        guard code == 200 else { return [] }
        rawData = data
    } catch {
        print("❌ \(year) Index.json request failed: \(error)")
        return []
    }
    guard let json = try? JSONSerialization.jsonObject(with: ReplayLoader.stripBOM(rawData)) as? [String: Any],
          let meetings = json["Meetings"] as? [[String: Any]]
    else {
        print("❌ \(year) Index.json parse failed: \(String(decoding: rawData.prefix(200), as: UTF8.self))")
        return []
    }

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
