//
//  TrackMapView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/3/26.
//


import SwiftUI

struct TrackMapView: View {
    @ObservedObject var store: F1SessionStore
    @AppStorage("isDark") private var isDark = false
    
//    @State private var trailGrid: [GridKey: [(x: Double, y: Double)]] = [:]
//    @State private var lastSessionPath: String?
//    private let minTrailSpacing: Double = 50
//    private var cellSize: Double { minTrailSpacing }
    
    @ObservedObject var VM: TrackMapViewModel

    private var positionedDrivers: [(driver: Driver, pos: CarPosition)] {
        store.drivers.compactMap { driver in
            guard let pos = store.carPositions[driver.id] else { return nil }
            return (driver, pos)
        }
    }

    private var bounds: (minX: Double, maxX: Double, minY: Double, maxY: Double)? {
        let pts = positionedDrivers.map { $0.pos }
        guard !pts.isEmpty else { return nil }
        let xs = pts.map { $0.x }
        let ys = pts.map { $0.y }
        return (xs.min()!, xs.max()!, ys.min()!, ys.max()!)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let b = bounds, b.maxX > b.minX, b.maxY > b.minY {
                    ForEach(Array(VM.trailGrid.values.flatMap { $0 }.enumerated()), id: \.offset) { _, tp in
                        let point = projected(CarPosition(x: tp.x, y: tp.y, z: 0, status: ""), in: geo.size, bounds: b)
                        Circle()
                            .fill(isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.15))
                            .frame(width: 3, height: 3)
                            .position(point)
                    }
                    
                    ForEach(positionedDrivers, id: \.driver.id) { entry in
                        let point = projected(entry.pos, in: geo.size, bounds: b)
                        VStack(spacing: 2) {
                            Circle()
                                .fill(entry.driver.teamColour)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            Text(entry.driver.tla)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(isDark ? .white : .black)
                        }
                        .position(point)
                    }
                } else {
                    Text("Waiting for position data…")
                        .foregroundStyle(.secondary)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding()
        .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
        .cornerRadius(12)
        .onChange(of: store.updateCount) { _, _ in
            for entry in positionedDrivers {
                maybeAddTrailPoint(entry.pos)
            }
        }
        .onChange(of: (store.rawTopics["SessionInfo"] as? [String: Any])?["Path"] as? String) { _, newPath in
            guard newPath != VM.lastSessionPath else { return }
            VM.lastSessionPath = newPath
            VM.trailGrid.removeAll()
        }
    }

    private func projected(_ pos: CarPosition, in size: CGSize, bounds b: (minX: Double, maxX: Double, minY: Double, maxY: Double)) -> CGPoint {
        let padding: CGFloat = 24
        let usableW = size.width - padding * 2
        let usableH = size.height - padding * 2

        let nx = (pos.x - b.minX) / (b.maxX - b.minX)
        let ny = (pos.y - b.minY) / (b.maxY - b.minY)

        return CGPoint(
            x: padding + CGFloat(nx) * usableW,
            y: padding + (1 - CGFloat(ny)) * usableH // flip so track orientation feels natural
        )
    }
    
    private func gridKey(for x: Double, _ y: Double) -> GridKey {
        GridKey(cx: Int(floor(x / VM.cellSize)), cy: Int(floor(y / VM.cellSize)))
    }

    private func maybeAddTrailPoint(_ p: CarPosition) {
        let key = gridKey(for: p.x, p.y)

        for dx in -1...1 {
            for dy in -1...1 {
                let neighborKey = GridKey(cx: key.cx + dx, cy: key.cy + dy)
                if let points = VM.trailGrid[neighborKey] {
                    for existing in points {
                        let ddx = existing.x - p.x
                        let ddy = existing.y - p.y
                        if (ddx * ddx + ddy * ddy) < (VM.minTrailSpacing * VM.minTrailSpacing) {
                            return
                        }
                    }
                }
            }
        }

        VM.trailGrid[key, default: []].append((x: p.x, y: p.y))
    }
}
