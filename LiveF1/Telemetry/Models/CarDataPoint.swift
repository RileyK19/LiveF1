//
//  CarDataPoint.swift
//  LiveF1
//
//  Created by Riley Koo on 7/5/26.
//

import Combine
import Foundation

struct CarDataPoint: Codable, Identifiable {
    let date: Date
    let driverNumber: Int
    let speed: Int?
    let throttle: Int?
    let brake: Int?
    let nGear: Int?
    let rpm: Int?
    let drs: Int?

    var id: Date { date }

    enum CodingKeys: String, CodingKey {
        case date, speed, throttle, brake, rpm, drs
        case driverNumber = "driver_number"
        case nGear = "n_gear"
    }
}
