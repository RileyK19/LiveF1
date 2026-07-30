//
//  RaceControlMessage.swift
//  LiveF1
//
//  Created by Riley Koo on 7/29/26.
//

import Foundation

struct RaceControlMessage: Identifiable, Hashable {
    let id: String          // utc + message hash, for uniqueness
    let utc: String
    let lap: Int?
    let category: String    // "Flag", "SafetyCar", "Drs", "CarEvent", "Other"
    let message: String
    let flag: String?       // "GREEN", "YELLOW", "DOUBLE YELLOW", "RED", "CLEAR", "BLUE", "CHEQUERED"
    let scope: String?      // "Track", "Sector", "Driver"
    let sector: Int?
    let driverNumber: String?
}
