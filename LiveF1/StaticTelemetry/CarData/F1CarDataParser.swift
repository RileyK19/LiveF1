//
//  F1CarDataParser.swift
//  LiveF1
//
//  Created by Riley Koo on 7/5/26.
//

import Combine
import Foundation

struct F1CarDataParser {

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

    static func parse(data: Data) throws -> [CarDataPoint] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = dateFormatter.date(from: string) { return date }
            if let date = dateFormatterNoFraction.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Cannot parse date: \(string)")
        }
        return try decoder.decode([CarDataPoint].self, from: data)
    }

    /// Fetch car telemetry, optionally bounded to a date window (e.g. one lap)
    static func fetchLive(
        sessionKey: String,
        driverNumber: Int,
        dateStart: Date? = nil,
        dateEnd: Date? = nil,
        completion: @escaping (Result<[CarDataPoint], Error>) -> Void
    ) {
        var urlString = "https://api.openf1.org/v1/car_data?session_key=\(sessionKey)&driver_number=\(driverNumber)"

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let start = dateStart {
            urlString += "&date>=\(iso.string(from: start))"
        }
        if let end = dateEnd {
            urlString += "&date<=\(iso.string(from: end))"
        }

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
        dateStart: Date? = nil,
        dateEnd: Date? = nil
    ) async throws -> [CarDataPoint] {
        try await withCheckedThrowingContinuation { continuation in
            fetchLive(sessionKey: sessionKey, driverNumber: driverNumber,
                      dateStart: dateStart, dateEnd: dateEnd) {
                continuation.resume(with: $0)
            }
        }
    }

    enum ParseError: LocalizedError {
        case invalidEncoding, invalidURL, noData
        var errorDescription: String? {
            switch self {
            case .invalidEncoding: return "JSON string could not be encoded to Data"
            case .invalidURL:      return "Could not construct a valid URL"
            case .noData:          return "No data returned from the API"
            }
        }
    }
}
