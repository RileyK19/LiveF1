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

    @Published var samples: [CarDataPoint] = []
    @Published var isLoading = false
    @Published var error: String?

    init(session: F1PredictorSession) {
        self.session = session
    }

    func loadLap(_ lap: F1Lap, driverNumber: Int) async {
        guard let start = lap.dateStart, let duration = lap.lapDuration else {
            error = "Lap is missing timing data"
            return
        }
        isLoading = true
        error = nil
        do {
            samples = try await F1CarDataParser.fetchLive(
                sessionKey: "\(session.sessionKey)",
                driverNumber: driverNumber,
                dateStart: start,
                dateEnd: start.addingTimeInterval(duration)
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
