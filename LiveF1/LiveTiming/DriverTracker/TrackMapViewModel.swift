//
//  TrackMapViewModel.swift
//  LiveF1
//
//  Created by Riley Koo on 7/22/26.
//

import SwiftUI
import Combine
import Observation

@MainActor
@Observable
class TrackMapViewModel: Equatable, Hashable {
    public var trailGrid: [GridKey: [(x: Double, y: Double)]] = [:]
    @ObservationIgnored public var lastSessionPath: String?
    public let minTrailSpacing: Double = 50
    public var cellSize: Double
    public var id: UUID = UUID()
    
    init() {
        id = UUID()
        trailGrid = [:]
        lastSessionPath = nil
        cellSize = minTrailSpacing
    }
    
    static func == (lhs: TrackMapViewModel, rhs: TrackMapViewModel) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    func reset() {
        trailGrid = [:]
        lastSessionPath = nil
        cellSize = minTrailSpacing
    }
}

struct GridKey: Hashable {
    let cx: Int
    let cy: Int
}
