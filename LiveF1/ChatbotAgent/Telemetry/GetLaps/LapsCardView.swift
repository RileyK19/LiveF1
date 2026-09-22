//
//  LapsCardView.swift
//  Redline
//
//  Created by Riley Koo on 9/20/26.
//


//  LapsCardView.swift
//  Redline
//

import SwiftUI

struct LapsCardView: View {
    let laps: [LapSummary]
    let result: GetLapsResult

    private let rowHeight: CGFloat = 26
    private let maxVisibleRows = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !result.success {
                Text(result.errorMessage ?? "Couldn't load lap times.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                header

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(laps.enumerated()), id: \.offset) { _, lap in
                            row(lap)
                        }
                    }
                }
                .frame(height: CGFloat(min(laps.count, maxVisibleRows)) * rowHeight)
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack {
            Text("Lap Times")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if let race = result.raceName, let session = result.sessionType {
                Text("· \(race) \(session)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func row(_ lap: LapSummary) -> some View {
        let isBest = lap.gapToFastest == "—"
        return HStack(spacing: 8) {
            Text("L\(lap.lapNumber)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
            Text(lap.driverName)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            Text(lap.lapTime)
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(isBest ? Color.green : Color.primary)
            Text(lap.gapToFastest)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
        .frame(height: rowHeight)
    }
}
