//
//  F1LapParser.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//

import Foundation

// MARK: - Parser

struct F1LapParser {

    // Custom date formatter to handle OpenF1's ISO8601 with fractional seconds and timezone
    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private static let dateFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(data: Data) throws -> [F1Lap] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = dateFormatter.date(from: string) { return date }
            if let date = dateFormatterNoFraction.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Cannot parse date: \(string)")
        }
        return try decoder.decode([F1Lap].self, from: data)
    }

    static func parse(jsonString: String) throws -> [F1Lap] {
        guard let data = jsonString.data(using: .utf8) else {
            throw ParseError.invalidEncoding
        }
        return try parse(data: data)
    }

    /// Fetch live laps from OpenF1 for the current session
    static func fetchLive(
        sessionKey: String = "latest",
        driverNumber: Int? = nil,
        lapNumber: Int? = nil,
        completion: @escaping (Result<[F1Lap], Error>) -> Void
    ) {
        var components = URLComponents(string: "https://api.openf1.org/v1/laps")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "session_key", value: sessionKey)
        ]
        if let driver = driverNumber {
            queryItems.append(URLQueryItem(name: "driver_number", value: "\(driver)"))
        }
        if let lap = lapNumber {
            queryItems.append(URLQueryItem(name: "lap_number", value: "\(lap)"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            completion(.failure(ParseError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(ParseError.noData))
                return
            }
            do {
                let laps = try parse(data: data)
                completion(.success(laps))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    /// Async/await version
    @available(iOS 15, macOS 12, *)
    static func fetchLive(
        sessionKey: String = "latest",
        driverNumber: Int? = nil,
        lapNumber: Int? = nil
    ) async throws -> [F1Lap] {
        try await withCheckedThrowingContinuation { continuation in
            fetchLive(sessionKey: sessionKey, driverNumber: driverNumber, lapNumber: lapNumber) {
                continuation.resume(with: $0)
            }
        }
    }

    enum ParseError: LocalizedError {
        case invalidEncoding
        case invalidURL
        case noData

        var errorDescription: String? {
            switch self {
            case .invalidEncoding: return "JSON string could not be encoded to Data"
            case .invalidURL:      return "Could not construct a valid URL"
            case .noData:          return "No data returned from the API"
            }
        }
    }
}

// MARK: - Convenience grouping

extension Array where Element == F1Lap {

    /// Group laps by driver number
    var byDriver: [Int: [F1Lap]] {
        Dictionary(grouping: self, by: \.driverNumber)
    }

    /// Fastest lap per driver
    var fastestLapPerDriver: [Int: F1Lap] {
        byDriver.compactMapValues { laps in
            laps.filter { $0.lapDuration != nil }
                .min(by: { $0.lapDuration! < $1.lapDuration! })
        }
    }

    /// Sort by lap time ascending, nil durations go to the end
    var sortedByLapTime: [F1Lap] {
        sorted {
            switch ($0.lapDuration, $1.lapDuration) {
            case let (a?, b?): return a < b
            case (nil, _):     return false
            case (_, nil):     return true
            }
        }
    }
}

// MARK: - Usage example

/*

// --- Parse from a local JSON string ---
let json = """
[
  {
    "meeting_key": 1287,
    "session_key": 11307,
    "driver_number": 44,
    "lap_number": 2,
    "date_start": "2026-06-14T13:05:01.283000+00:00",
    "duration_sector_1": null,
    "duration_sector_2": 34.537,
    "duration_sector_3": 25.734,
    "i1_speed": null,
    "i2_speed": 254,
    "is_pit_out_lap": false,
    "lap_duration": 84.536,
    "segments_sector_1": [2049, 2049, 2049, 0, 0, 0, 0],
    "segments_sector_2": [null, null, 2049, 2049, 2049, 2049, 2049, 2049],
    "segments_sector_3": [2049, 2048, 2048, 2049, 2049, 2048, 2048],
    "st_speed": 334
  }
]
"""

let laps = try F1LapParser.parse(jsonString: json)
print(laps[0].formattedLapTime)   // "1:24.536"

// --- Fetch live from OpenF1 ---
Task {
    let liveLaps = try await F1LapParser.fetchLive()          // all drivers, latest session
    let leaderboard = liveLaps.fastestLapPerDriver
        .sorted { $0.value.lapDuration! < $1.value.lapDuration! }
    for (rank, entry) in leaderboard.enumerated() {
        print("\(rank + 1). #\(entry.key) — \(entry.value.formattedLapTime)")
    }
}

// --- Fetch a specific driver ---
Task {
    let hamiltonLaps = try await F1LapParser.fetchLive(driverNumber: 44)
    hamiltonLaps.sortedByLapTime.forEach {
        print("Lap \($0.lapNumber): \($0.formattedLapTime)")
    }
}

*/
