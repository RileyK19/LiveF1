//
//  HypotheticalStintExportLayout.swift
//  Redline
//
//  Created by Riley Koo on 9/27/26.
//

import SwiftUI

struct HypotheticalStintExportLayout: View {
    let driverName: String
    let timeDelta: Double?
    let actual: [F1PredictorStint]
    let hypothetical: [F1PredictorStint]
    let trackEvolutionModel: TrackEvolutionCalculator.TrackEvolutionModel?
    let selectedDriverNumber: Int?
    let medianLapTime: Double
    let annotatedLaps: [AnnotatedLap]
    let sessionName: String
    let generatedDate: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            
            dataView

            footer
        }
        .padding(32)
        .background(Color.white)
    }
    
    private var dataView: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            if let delta = timeDelta {
                HStack {
                    Image(systemName: delta < 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(delta < 0 ? .green : .red)
                    Text(delta < 0
                         ? "Hypothetical is \(formatDelta(delta)) faster"
                         : "Hypothetical is \(formatDelta(delta)) slower")
                    .font(.subheadline.bold())
                }
            }
            
            StintComparisonPage(actual: actual, hypothetical: hypothetical)
            
            Text("Hypothetical delta to actual")
                .font(.subheadline.bold())
            
            DeltaChartPage(
                timeDelta: timeDelta,
                trackEvolutionModel: trackEvolutionModel,
                selectedDriverNumber: selectedDriverNumber,
                actual: actual,
                hypothetical: hypothetical,
                medianLapTime: medianLapTime,
                annotatedLaps: annotatedLaps
            )
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hypothetical Stint Report for \(driverName)")
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
    
    
    private func formatDelta(_ seconds: Double) -> String {
        let sign = seconds >= 0 ? "+" : ""
        return String(format: "\(sign)%.1fs", seconds)
    }
}
