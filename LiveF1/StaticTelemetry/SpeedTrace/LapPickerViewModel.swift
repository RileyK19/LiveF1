//
//  LapPickerViewModel.swift
//  LiveF1
//
//  Created by Riley Koo on 7/5/26.
//

import Combine
import Foundation

@MainActor
class LapPickerViewModel: ObservableObject {
    let session: F1PredictorSession

    @Published var laps: [F1Lap] = []
    @Published var selectedDriverNumber: Int? = nil
    @Published var isLoading = false
    @Published var error: String?

    init(session: F1PredictorSession) {
        self.session = session
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            laps = try await F1LapParser.fetchLive(sessionKey: "\(session.sessionKey)")
            if selectedDriverNumber == nil {
                selectedDriverNumber = drivers.first
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    var drivers: [Int] {
        Array(Set(laps.map(\.driverNumber))).sorted()
    }

    var lapsForSelectedDriver: [F1Lap] {
        guard let driver = selectedDriverNumber else { return [] }
        return laps
            .filter { $0.driverNumber == driver && $0.lapDuration != nil }
            .sorted { $0.lapNumber < $1.lapNumber }
    }
}
