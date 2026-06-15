//
//  F1LapModels.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//

import Foundation

// MARK: - Models

struct F1Lap: Codable, Identifiable {
    var id: String { "\(sessionKey)-\(driverNumber)-\(lapNumber)" }

    let meetingKey: Int
    let sessionKey: Int
    let driverNumber: Int
    let lapNumber: Int
    let dateStart: Date?
    let durationSector1: Double?
    let durationSector2: Double?
    let durationSector3: Double?
    let i1Speed: Int?
    let i2Speed: Int?
    let isPitOutLap: Bool
    let lapDuration: Double?
    let segmentsSector1: [Int?]?
    let segmentsSector2: [Int?]?
    let segmentsSector3: [Int?]?
    let stSpeed: Int?

    // Computed helpers
    var totalSectorTime: Double? {
        guard let s1 = durationSector1, let s2 = durationSector2, let s3 = durationSector3 else { return nil }
        return s1 + s2 + s3
    }

    var formattedLapTime: String {
        guard let duration = lapDuration else { return "--:--.---" }
        let minutes = Int(duration) / 60
        let seconds = duration.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%06.3f", minutes, seconds)
    }

    enum CodingKeys: String, CodingKey {
        case meetingKey = "meeting_key"
        case sessionKey = "session_key"
        case driverNumber = "driver_number"
        case lapNumber = "lap_number"
        case dateStart = "date_start"
        case durationSector1 = "duration_sector_1"
        case durationSector2 = "duration_sector_2"
        case durationSector3 = "duration_sector_3"
        case i1Speed = "i1_speed"
        case i2Speed = "i2_speed"
        case isPitOutLap = "is_pit_out_lap"
        case lapDuration = "lap_duration"
        case segmentsSector1 = "segments_sector_1"
        case segmentsSector2 = "segments_sector_2"
        case segmentsSector3 = "segments_sector_3"
        case stSpeed = "st_speed"
    }
}

// MARK: - Segment color interpretation

/// Segment values from OpenF1 correspond to timing colours shown on track maps.
enum SegmentStatus: Int {
    case unknown = 0
    case yellow = 2048     // slower than personal best
    case green = 2049      // personal best
    case purple = 2051     // overall best (purple sector)
    case pitLane = 2064

    var label: String {
        switch self {
        case .unknown:  return "Unknown"
        case .yellow:   return "Yellow"
        case .green:    return "Green"
        case .purple:   return "Purple"
        case .pitLane:  return "Pit Lane"
        }
    }
}

