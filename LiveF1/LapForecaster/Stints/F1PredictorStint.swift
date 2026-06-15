//
//  F1PredictorStint.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//

import Foundation

struct F1PredictorStint: Codable, Identifiable {
    var id: String { "\(sessionKey)-\(driverNumber)-\(stintNumber)" }

    let meetingKey: Int
    let sessionKey: Int
    let stintNumber: Int
    let driverNumber: Int
    let lapStart: Int
    let lapEnd: Int?
    let compound: String
    let tyreAgeAtStart: Int

    var lapRange: ClosedRange<Int>? {
        guard let end = lapEnd, end >= lapStart else { return nil }
        return lapStart...end
    }

    var compoundEnum: TyreCompound {
        TyreCompound(rawValue: compound) ?? .unknown
    }

    enum CodingKeys: String, CodingKey {
        case meetingKey = "meeting_key"
        case sessionKey = "session_key"
        case stintNumber = "stint_number"
        case driverNumber = "driver_number"
        case lapStart = "lap_start"
        case lapEnd = "lap_end"
        case compound = "compound"
        case tyreAgeAtStart = "tyre_age_at_start"
    }
}

enum TyreCompound: String {
    case soft = "SOFT"
    case medium = "MEDIUM"
    case hard = "HARD"
    case intermediate = "INTERMEDIATE"
    case wet = "WET"
    case unknown = "UNKNOWN"

    var color: String {
        switch self {
        case .soft:         return "#FF3333"
        case .medium:       return "#FFD700"
        case .hard:         return "#CCCCCC"
        case .intermediate: return "#39B54A"
        case .wet:          return "#0067FF"
        case .unknown:      return "#888888"
        }
    }
}
