//
//  LocationPoint.swift
//  Redline
//
//  Created by Riley Koo on 8/27/26.
//

import Foundation

/// A single X/Y/Z sample from OpenF1's `location` endpoint.
struct LocationPoint: Codable {
    let date: Date
    let x: Double
    let y: Double
    let z: Double
    let driverNumber: Int

    enum CodingKeys: String, CodingKey {
        case date, x, y, z
        case driverNumber = "driver_number"
    }
}

struct LapPositionParser {

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

    static func parse(data: Data) throws -> [LocationPoint] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = dateFormatter.date(from: string) { return date }
            if let date = dateFormatterNoFraction.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Cannot parse date: \(string)")
        }
        return try decoder.decode([LocationPoint].self, from: data)
    }

    /// Fetch X/Y/Z position samples, bounded to a date window (e.g. one lap).
    /// `location` is OpenF1's heaviest/slowest endpoint — always pass a tight window.
    static func fetchLive(
        sessionKey: String,
        driverNumber: Int,
        dateStart: Date,
        dateEnd: Date,
        completion: @escaping (Result<[LocationPoint], Error>) -> Void
    ) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var urlString = "https://api.openf1.org/v1/location?session_key=\(sessionKey)&driver_number=\(driverNumber)"
        urlString += "&date>=\(iso.string(from: dateStart))"
        urlString += "&date<=\(iso.string(from: dateEnd))"

        guard let url = URL(string: urlString) else {
            completion(.failure(ParseError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(ParseError.noData)); return }
            do {
                completion(.success(try parse(data: data)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    @available(iOS 15, macOS 12, *)
    static func fetchLive(
        sessionKey: String,
        driverNumber: Int,
        dateStart: Date,
        dateEnd: Date
    ) async throws -> [LocationPoint] {
        try await withCheckedThrowingContinuation { continuation in
            fetchLive(sessionKey: sessionKey, driverNumber: driverNumber,
                      dateStart: dateStart, dateEnd: dateEnd) {
                continuation.resume(with: $0)
            }
        }
    }

    enum ParseError: LocalizedError {
        case invalidURL, noData
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Could not construct a valid URL"
            case .noData:     return "No data returned from the API"
            }
        }
    }
}
