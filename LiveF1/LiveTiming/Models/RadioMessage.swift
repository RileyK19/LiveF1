//
//  RadioMessage.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI

struct RadioMessage: Identifiable {
    let id: String  // Utc timestamp
    let driverNumber: String
    let driverTla: String
    let teamColour: Color
    let utc: String
    let audioURL: URL?
    var transcription: String?
}
