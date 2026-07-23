//
//  TrackMapViewModel.swift
//  LiveF1
//
//  Created by Riley Koo on 7/22/26.
//

import SwiftUI
import Combine

@MainActor
class TrackMapViewModel: ObservableObject {
    @Published public var trailGrid: [GridKey: [(x: Double, y: Double)]] = [:]
    @Published public var lastSessionPath: String?
    public let minTrailSpacing: Double = 50
    @Published public var cellSize: Double
    
    init() {
        trailGrid = [:]
        lastSessionPath = nil
        cellSize = minTrailSpacing
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
