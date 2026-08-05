//
//  TelemetryCard.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI

struct TelemetryCard: View {
    @AppStorage("isDark") private var isDark = false

    let label: String
    let value: String
    let unit: String
    let colour: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.title2.bold()).foregroundStyle(colour)
                if !unit.isEmpty {
                    Text(unit).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
        .cornerRadius(12)
    }
}
