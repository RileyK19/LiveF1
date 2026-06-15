//
//  F1PredictorStintParser.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//


//  F1PredictorStintParser.swift

import Foundation

struct F1PredictorStintParser {

    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func parse(data: Data) throws -> [F1PredictorStint] {
        let decoder = JSONDecoder()
        return try decoder.decode([F1PredictorStint].self, from: data)
    }

    static func parse(jsonString: String) throws -> [F1PredictorStint] {
        guard let data = jsonString.data(using: .utf8) else {
            throw ParseError.invalidEncoding
        }
        return try parse(data: data)
    }

    static func fetch(
        sessionKey: String = "latest",
        driverNumber: Int? = nil,
        completion: @escaping (Result<[F1PredictorStint], Error>) -> Void
    ) {
        var components = URLComponents(string: "https://api.openf1.org/v1/stints")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "session_key", value: sessionKey)
        ]
        if let driver = driverNumber {
            queryItems.append(URLQueryItem(name: "driver_number", value: "\(driver)"))
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
                let stints = try parse(data: data)
                completion(.success(stints))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    @available(iOS 15, macOS 12, *)
    static func fetch(
        sessionKey: String = "latest",
        driverNumber: Int? = nil
    ) async throws -> [F1PredictorStint] {
        try await withCheckedThrowingContinuation { continuation in
            fetch(sessionKey: sessionKey, driverNumber: driverNumber) {
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

extension Array where Element == F1PredictorStint {

    /// All stints for a specific driver, sorted by stint number
    func stints(for driverNumber: Int) -> [F1PredictorStint] {
        filter { $0.driverNumber == driverNumber }
            .sorted { $0.stintNumber < $1.stintNumber }
    }

    /// Find the stint a given lap falls into for a driver
    func stint(for driverNumber: Int, atLap lapNumber: Int) -> F1PredictorStint? {
        stints(for: driverNumber).first { stint in
            guard let range = stint.lapRange else { return false }
            return range.contains(lapNumber)
        }
    }

    /// Tyre age at a specific lap for a driver
    func tyreAge(for driverNumber: Int, atLap lapNumber: Int) -> Int? {
        guard let stint = stint(for: driverNumber, atLap: lapNumber) else { return nil }
        return (lapNumber - stint.lapStart) + stint.tyreAgeAtStart
    }
}