//
//  RacePaceExportLayout.swift
//  Redline
//
//  Created by Riley Koo on 9/25/26.
//

import SwiftUI

struct RacePaceExportLayout: View {
    let driverStats: [DriverPaceStats]
    let paceByLap: [Int: [DriverPaceStats]]
    let selectedDriverNumbers: Set<Int>
    let fastestLapTime: Double
    let sessionName: String
    let generatedDate: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            RacePaceBarChart(
                driverStats: driverStats,
                fastestLapTime: fastestLapTime,
                selectedDriverNumbers: .constant(selectedDriverNumbers)
            )

            RacePaceTimelineChart(
                paceByLap: paceByLap,
                selectedDriverNumbers: selectedDriverNumbers,
                showControls: false
            )

            footer
        }
        .padding(32)
        .background(Color.white)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Race Pace Report")
                .font(.system(size: 28, weight: .bold, design: .serif))
            Text(sessionName)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Text("Generated \(generatedDate.formatted(date: .abbreviated, time: .shortened))")
            Spacer()
            Text("Redline F1")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
