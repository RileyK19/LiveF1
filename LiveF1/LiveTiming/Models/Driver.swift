//
//  Driver.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI

struct Driver: Identifiable, Hashable {
    let id: String          // racing number
    var position: Int
    var tla: String         // VER, HAM etc
    var fullName: String
    var teamName: String
    var teamColour: Color
    var gap: String
    var interval: String
    var lastLap: String
    var isPersonalBest: Bool
    var sector1: String
    var sector2: String
    var sector3: String
    var compound: String    // SOFT, MEDIUM, HARD etc
    var tyreAge: Int
    var pits: Int
    var inPit: Bool
    var bestLap: String
    var isBestLap: Bool
    var segments: [[Int]]
    var sectorDelta: String
}
