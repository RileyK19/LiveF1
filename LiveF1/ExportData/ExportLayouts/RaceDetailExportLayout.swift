//
//  RaceDetailExportLayout.swift
//  Redline
//
//  Created by Riley Koo on 9/27/26.
//

import SwiftUI

struct RaceDetailExportLayout: View {
    let annotatedLaps: [AnnotatedLap]
    let stintRegressionLines: [(
        stint: F1PredictorStint,
         model: DegradationModel,
         laps: [AnnotatedLap]
    )]
    let rawLapTimeRange: ClosedRange<Double>
    
    let adjustedAnnotatedLaps: [AnnotatedLap]
    let adjustedStintRegressionLines: [(
        stint: F1PredictorStint,
        model: DegradationModel,
        laps: [AnnotatedLap]
    )]
    let adjustedLapTimeRange: ClosedRange<Double>
    
    let usedCompounds: [TyreCompound]
    let stintsForSelectedDriver: [F1PredictorStint]
    let selectedDriver: Int
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
        VStack {
            HStack {
                VStack {
                    Text("Raw Lap Times")
                    LapTimeRawChartView(
                        annotatedLaps: annotatedLaps,
                        stintRegressionLines: stintRegressionLines,
                        rawLapTimeRange: rawLapTimeRange
                    )
                    .clipped()
                }
                VStack {
                    Text("Adjusted for Track Evolution")
                    LapTimeAdjustedChartView(
                        adjustedAnnotatedLaps: adjustedAnnotatedLaps,
                        adjustedStintRegressionLines: adjustedStintRegressionLines,
                        adjustedLapTimeRange: adjustedLapTimeRange
                    )
                    .clipped()
                }
            }
            
            LapTimeCompoundLegend(usedCompounds: usedCompounds)
                .padding(.horizontal)

            LapTimeStintSummary(stintsForSelectedDriver: stintsForSelectedDriver)
                .padding(.horizontal)
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lap Times Report for #\(selectedDriver)")
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
