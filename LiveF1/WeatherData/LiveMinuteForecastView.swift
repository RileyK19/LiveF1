//
//  LiveMinuteForecastView.swift
//  Redline
//
//  Created by Riley Koo on 8/22/26.
//


import Charts
import WeatherKit
import SwiftUI

struct LiveMinuteForecastView: View {
    let readings: [MinuteWeather]

    var body: some View {
        if readings.isEmpty {
            Text("Live minute-by-minute forecast isn't available for this location.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Next 60 min — precipitation chance")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Chart(readings, id: \.date) { minute in
                    AreaMark(
                        x: .value("Time", minute.date),
                        y: .value("Chance", minute.precipitationChance)
                    )
                    .foregroundStyle(.blue.opacity(0.3))
                    LineMark(
                        x: .value("Time", minute.date),
                        y: .value("Chance", minute.precipitationChance)
                    )
                    .foregroundStyle(.blue)
                }
                .chartYScale(domain: 0...1)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .minute, count: 15)) { _ in
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 60)
            }
            .padding(.leading, 8)
            .padding(.bottom, 6)
        }
    }
}
