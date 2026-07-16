//
//  SpeedTraceViewModel.swift
//  LiveF1
//
//  Created by Riley Koo on 7/5/26.
//

import Combine
import Foundation

@MainActor
class SpeedTraceViewModel: ObservableObject {
    let session: F1PredictorSession

    struct Sample: Identifiable {
        let id = UUID()
        let label: String
        let elapsed: Double
        let speed: Int?
        let throttle: Int?
        let brake: Int?
    }

    @Published var samples: [Sample] = []
    @Published var isLoading = false
    @Published var error: String?

    init(session: F1PredictorSession) {
        self.session = session
    }

    func loadLaps(_ laps: [F1Lap]) async {
        isLoading = true
        error = nil
        var all: [Sample] = []

        for lap in laps {
            guard let start = lap.dateStart, let duration = lap.lapDuration else { continue }
            let label = "#\(lap.driverNumber) L\(lap.lapNumber)"
            do {
                let raw = try await F1CarDataParser.fetchLive(
                    sessionKey: "\(session.sessionKey)",
                    driverNumber: lap.driverNumber,
                    dateStart: start,
                    dateEnd: start.addingTimeInterval(duration)
                )
                all.append(contentsOf: raw.map {
                    Sample(
                        label: label,
                        elapsed: $0.date.timeIntervalSince(start),
                        speed: $0.speed,
                        throttle: $0.throttle,
                        brake: $0.brake
                    )
                })
            } catch {
                self.error = error.localizedDescription
            }
        }

        samples = all
        isLoading = false
    }
}
