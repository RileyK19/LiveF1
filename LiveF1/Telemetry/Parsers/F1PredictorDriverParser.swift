//
//  F1PredictorDriverParser.swift
//  Redline
//
//  Created by Riley Koo on 9/8/26.
//

import Foundation

struct F1PredictorDriver: Codable {
    let driverNumber: Int
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case fullName = "full_name"
    }
}

struct F1PredictorDriverParser {
    static func fetch(sessionKey: String) async throws -> [F1PredictorDriver] {
        var components = URLComponents(string: "https://api.openf1.org/v1/drivers")!
        components.queryItems = [URLQueryItem(name: "session_key", value: sessionKey)]
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([F1PredictorDriver].self, from: data)
    }
}
