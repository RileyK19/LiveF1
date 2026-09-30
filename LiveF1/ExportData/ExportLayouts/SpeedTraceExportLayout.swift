//
//  SpeedTraceExportLayout.swift
//  Redline
//
//  Created by Riley Koo on 9/27/26.
//


import SwiftUI

struct SpeedTraceExportLayout: View {
    let samples: [SpeedTraceSample]
    let deltaSamples: [SpeedTraceSample]
    let sessionName: String
    let generatedDate: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            
            SpeedTraceChartsView(
                samples: samples,
                deltaSamples: deltaSamples,
                zoom: (samples.map(\.elapsed).max() ?? 60)
            )

            footer
        }
        .padding(32)
        .background(Color.white)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Speed Trace Report")
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
