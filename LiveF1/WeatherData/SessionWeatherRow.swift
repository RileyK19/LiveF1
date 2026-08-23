//
//  SessionWeatherRow.swift
//  Redline
//
//  Created by Riley Koo on 8/22/26.
//

import SwiftUI
import WeatherKit


struct SessionWeatherRow: View {
    let sessionWeather: SessionWeather
    @State private var isExpanded = false
    @ObservedObject var viewModel: WeatherViewModel

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d · HH:mm"
        f.timeZone = .current
        return f.string(from: sessionWeather.sessionDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sessionWeather.sessionName)
                        .font(.headline)
                    Text(timeString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let symbolName = sessionWeather.symbolName {
                    Image(systemName: symbolName)
                        .font(.title2)
                        .symbolRenderingMode(.multicolor)
                }

                VStack(alignment: .trailing, spacing: 4) {
                    if let temp = sessionWeather.temperature {
                        Text(temp.formatted(
                            .measurement(width: .narrow, usage: .weather,
                                         numberFormatStyle: .number.precision(.fractionLength(2)))))
                            .font(.headline)
                        if let chance = sessionWeather.precipitationChance {
                            Label("\(Int(chance * 100))%", systemImage: "drop.fill")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    } else {
                        Text("Not available yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if sessionWeather.hourlyReadings.count > 1 {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.leading, 4)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                guard sessionWeather.hourlyReadings.count > 1 else { return }
                withAnimation(.snappy) { isExpanded.toggle() }
            }

            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(sessionWeather.hourlyReadings, id: \.date) { hour in
                        HStack {
                            Text(hour.date, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)

                            Image(systemName: hour.symbolName)
                                .symbolRenderingMode(.multicolor)
                                .font(.caption)

                            Spacer()

                            Text(hour.temperature.formatted(
                                .measurement(width: .narrow, usage: .weather,
                                             numberFormatStyle: .number.precision(.fractionLength(1)))))
                                .font(.caption)

                            Label("\(Int(hour.precipitationChance * 100))%", systemImage: "drop.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.leading, 8)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
                
                if viewModel.isLiveIsh(sessionWeather) {
                    LiveMinuteForecastView(readings: viewModel.minuteReadings)
                        .task {
                            await viewModel.loadMinuteForecast()
                            while !Task.isCancelled {
                                try? await Task.sleep(for: .seconds(60))
                                await viewModel.loadMinuteForecast()
                            }
                        }
                }
            }
        }
    }
}
