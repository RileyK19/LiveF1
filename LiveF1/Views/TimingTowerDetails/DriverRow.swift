//
//  DriverRow.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI

struct DriverRow: View {
    @AppStorage("isDark") private var isDark = false

    let driver: Driver
    let isLeader: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("\(driver.position)")
                .frame(width: 20, alignment: .center)
                .foregroundStyle(isDark ? .white : .black)

            HStack(spacing: 3) {
                Rectangle()
                    .fill(driver.teamColour)
                    .frame(width: 3, height: 18)
                    .cornerRadius(1.5)
                Text(driver.tla)
                    .foregroundStyle(isDark ? .white : .black)
            }
            .frame(width: 36, alignment: .leading)

            Text(driver.bestLap)
                .frame(width: 100, alignment: .trailing)
                .foregroundStyle(driver.isBestLap ? .purple : isDark ? .white : .black)

            Text(driver.lastLap)
                .foregroundStyle(
                    driver.isBestLap ? .purple :
                    driver.isPersonalBest ? .green : isDark ? .white : .black
                )
                .frame(width: 100, alignment: .trailing)
                .foregroundStyle(driver.isBestLap ? .purple : isDark ? .white : .black)

            Text(isLeader ? "—" : driver.gap)
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(.gray)

            MiniSectors(segments: driver.segments, delta: driver.sectorDelta)
                .frame(width: 150, alignment: .leading)

            HStack(spacing: 2) {
                TyreBadge(compound: driver.compound, age: driver.tyreAge)
            }
            .frame(width: 52, alignment: .center)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(driver.inPit ? (isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)) : Color.clear)
    }
}
