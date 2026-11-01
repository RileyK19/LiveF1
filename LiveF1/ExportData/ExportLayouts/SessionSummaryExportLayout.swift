//
//  SessionSummaryExportLayout.swift
//  Redline
//
//  Created by Riley Koo on 11/1/26.
//

import SwiftUI

struct SessionSummaryExportLayout: View {
    let sessionName: String
    let stints: [StintSeries]
    let refs: [String: Double]
    let summary: [CompoundSummary]
    let generatedDate: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            dataView

            footer
        }
        .padding(32)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private var dataView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if stints.isEmpty {
                Text("Not enough long-run data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                StintChart(stints: stints, refs: refs)
                SummaryTable(rows: summary)

                Text("Fuel-corrected, stints of \(Tuning.minStintLaps)+ laps, shown vs each driver's best run. Summary uses drivers who ran 2+ compounds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Session Summary")
                .font(.system(size: 28, weight: .bold, design: .serif))
            Text(sessionName)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        VStack {
            HStack {
                Text("*Estimates only, may occasionally be inaccurate. Use as a guide, not fact. :)")
                Spacer()
            }

            HStack {
                Text("Generated \(generatedDate.formatted(date: .abbreviated, time: .shortened))")
                Spacer()
                Text("Redline F1")
                    .fontWeight(.semibold)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
