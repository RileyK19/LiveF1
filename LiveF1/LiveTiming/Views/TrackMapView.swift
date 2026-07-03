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

    private var positionedDrivers: [(driver: Driver, pos: CarPosition)] {
        store.drivers.compactMap { driver in
            guard let pos = store.carPositions[driver.id] else { return nil }
            return (driver, pos)
        }
    }

    private var bounds: (minX: Double, maxX: Double, minZ: Double, maxZ: Double)? {
        let pts = positionedDrivers.map { $0.pos }
        guard !pts.isEmpty else { return nil }
        let xs = pts.map { $0.x }
        let zs = pts.map { $0.z }
        return (xs.min()!, xs.max()!, zs.min()!, zs.max()!)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let b = bounds, b.maxX > b.minX, b.maxZ > b.minZ {
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
    }

    private func projected(_ pos: CarPosition, in size: CGSize, bounds b: (minX: Double, maxX: Double, minZ: Double, maxZ: Double)) -> CGPoint {
        let padding: CGFloat = 24
        let usableW = size.width - padding * 2
        let usableH = size.height - padding * 2

        let nx = (pos.x - b.minX) / (b.maxX - b.minX)
        let nz = (pos.z - b.minZ) / (b.maxZ - b.minZ)

        return CGPoint(
            x: padding + CGFloat(nx) * usableW,
            y: padding + (1 - CGFloat(nz)) * usableH // flip so track orientation feels natural
        )
    }
}