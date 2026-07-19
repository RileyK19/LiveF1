//
//  SessionWeather.swift
//  LiveF1
//
//  Created by Riley Koo on 7/19/26.
//


//
//  WeatherView.swift
//  LiveF1
//
//  Shows predicted temperature + chance of rain for each session of a race weekend,
//  scoped strictly to the session window (no "before session" data shown).
//
//  NOTE: Requires the WeatherKit capability enabled in Signing & Capabilities.
//  Forward geocoding (CLGeocoder) does not require location permission.
//

import SwiftUI
import WeatherKit
import CoreLocation
import Combine

// MARK: - Model

struct SessionWeather: Identifiable {
    let id = UUID()
    let sessionName: String
    let sessionDate: Date
    let temperature: Measurement<UnitTemperature>?
    let precipitationChance: Double?   // 0.0 - 1.0
    let symbolName: String?
}
