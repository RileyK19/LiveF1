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
    let allowsMultipleSelection: Bool

    @Published var laps: [F1Lap] = []
    @Published var selectedDriverNumber: Int? = nil
    @Published var isLoading = false
    @Published var error: String?

    @Published var selectedLaps: [F1Lap] = []

    init(session: F1PredictorSession, allowsMultipleSelection: Bool = true) {
        self.session = session
        self.allowsMultipleSelection = allowsMultipleSelection
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

    func isSelected(_ lap: F1Lap) -> Bool {
        selectedLaps.contains { $0.id == lap.id }
    }

    func toggleSelection(_ lap: F1Lap) {
        guard allowsMultipleSelection else {
            // Single-select: tapping the selected lap deselects it, tapping another replaces it.
            selectedLaps = isSelected(lap) ? [] : [lap]
            return
        }
        if let index = selectedLaps.firstIndex(where: { $0.id == lap.id }) {
            selectedLaps.remove(at: index)
        } else {
            selectedLaps.append(lap)
        }
    }
}
