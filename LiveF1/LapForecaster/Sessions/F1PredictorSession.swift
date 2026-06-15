//
//  F1Session.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//

import Foundation

struct F1PredictorSession: Codable, Identifiable {
    var id: Int { sessionKey }

    let sessionKey: Int
    let sessionType: String
    let sessionName: String
    let dateStart: Date?
    let dateEnd: Date?
    let meetingKey: Int
    let circuitKey: Int
    let circuitShortName: String
    let countryKey: Int
    let countryCode: String
    let countryName: String
    let location: String
    let gmtOffset: String
    let year: Int
    let isCancelled: Bool

    enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case sessionType = "session_type"
        case sessionName = "session_name"
        case dateStart = "date_start"
        case dateEnd = "date_end"
        case meetingKey = "meeting_key"
        case circuitKey = "circuit_key"
        case circuitShortName = "circuit_short_name"
        case countryKey = "country_key"
        case countryCode = "country_code"
        case countryName = "country_name"
        case location = "location"
        case gmtOffset = "gmt_offset"
        case year = "year"
        case isCancelled = "is_cancelled"
    }
}
