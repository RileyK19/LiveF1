//
//  F1PredictorSessionParser.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//

import Foundation

struct F1PredictorSessionParser {

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

    static func parse(data: Data) throws -> [F1PredictorSession] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = dateFormatter.date(from: string) { return date }
            if let date = dateFormatterNoFraction.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Cannot parse date: \(string)")
        }
        return try decoder.decode([F1PredictorSession].self, from: data)
    }

    static func parse(jsonString: String) throws -> [F1PredictorSession] {
        guard let data = jsonString.data(using: .utf8) else {
            throw ParseError.invalidEncoding
        }
        return try parse(data: data)
    }

    static func fetchRaces(
        year: Int = 2026,
        completion: @escaping (Result<[F1PredictorSession], Error>) -> Void
    ) {
        var components = URLComponents(string: "https://api.openf1.org/v1/sessions")!
        components.queryItems = [
            URLQueryItem(name: "year", value: "\(year)"),
            URLQueryItem(name: "session_type", value: "Race")
        ]

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
                let sessions = try parse(data: data)
                completion(.success(sessions))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    @available(iOS 15, macOS 12, *)
    static func fetchRaces(year: Int = 2026) async throws -> [F1PredictorSession] {
        try await withCheckedThrowingContinuation { continuation in
            fetchRaces(year: year) {
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

extension Array where Element == F1PredictorSession {

    var sortedByDate: [F1PredictorSession] {
        sorted {
            guard let a = $0.dateStart, let b = $1.dateStart else { return false }
            return a < b
        }
    }

    var completed: [F1PredictorSession] {
        filter {
            guard let end = $0.dateEnd else { return false }
            return end < Date()
        }
    }

    var upcoming: [F1PredictorSession] {
        filter {
            guard let start = $0.dateStart else { return false }
            return start > Date()
        }
    }
}
