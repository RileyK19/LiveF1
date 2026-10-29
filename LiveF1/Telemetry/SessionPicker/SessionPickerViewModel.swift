//
//  SessionPickerViewModel.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//


//  SessionPickerViewModel.swift

import Foundation
import Combine

@MainActor
class SessionPickerViewModel: ObservableObject {
    @Published var sessions: [F1PredictorSession] = []
    @Published var isLoading = false
    @Published var error: String?

    let sessionType: [String]

    init(sessionType: String? = "Race") { // default preserves old behavior
        if let sessionType = sessionType {
            self.sessionType = [sessionType]
        } else {
            self.sessionType = []
        }
    }
    
    init(sessionType: [String]) {
        self.sessionType = sessionType
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            if sessionType.count > 1 {
                let fetched = try await F1PredictorSessionParser.fetchRacesWithLaps(year: 2026, sessionType: nil)
                sessions = fetched
                    .filter { sessionType.contains($0.sessionType) }
                    .sortedByDate
            } else if !sessionType.isEmpty {
                let fetched = try await F1PredictorSessionParser.fetchRacesWithLaps(year: 2026, sessionType: sessionType[0])
                sessions = fetched.sortedByDate
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
