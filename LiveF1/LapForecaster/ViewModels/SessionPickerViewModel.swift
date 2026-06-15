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
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    func load() async {
        isLoading = true
        error = nil
        do {
            let fetched = try await F1PredictorSessionParser.fetchRaces(year: 2026)
            sessions = fetched.sortedByDate
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
