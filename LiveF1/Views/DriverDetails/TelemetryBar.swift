//
//  TelemetryBar.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI

struct TelemetryBar: View {
    @AppStorage("isDark") private var isDark = false

    let label: String
    let value: Double
    let colour: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value * 100))%").font(.caption.bold()).foregroundStyle(colour)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    RoundedRectangle(cornerRadius: 4).fill(colour)
                        .frame(width: geo.size.width * value)
                        .animation(.linear(duration: 0.2), value: value)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
        .cornerRadius(12)
    }
}
