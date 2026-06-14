//
//  MiniSectors.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI

struct MiniSectors: View {
    @AppStorage("isDark") private var isDark = false

    let segments: [[Int]]
    let delta: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { sectorIndex in
                    HStack(spacing: 1) {
                        ForEach(0..<segments[sectorIndex].count, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(colour(for: segments[sectorIndex][i]))
                                .frame(width: 5, height: 10)
                        }
                    }
                    if sectorIndex < 2 {
                        Spacer().frame(width: 3)
                    }
                }
            }
            if !delta.isEmpty {
                Text(delta)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(delta.hasPrefix("+") ? .red : .green)
            }
        }
    }

    func colour(for status: Int) -> Color {
        switch status {
        case 2048: return .yellow      // completed, not fastest
        case 2049: return .green       // personal best
        case 2051: return .purple      // overall fastest
        case 2052: return .blue        // pit lane
        default:    return isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.15)  // not reached
        }
    }
}
