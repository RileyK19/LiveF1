//
//  SessionPickerViewModel.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//

import Foundation
import Combine

@MainActor
class SessionPickerViewModel: ObservableObject {
    @Published var sessions: [MultiF1PredictorSession] = []
    @Published var isLoading = false
    @Published var error: String?

    let sessionType: [String]
    
    var groupBy: [String] = []

    init(sessionType: String? = "Race", groupBy: [String] = []) {
        self.groupBy = groupBy
        if let sessionType = sessionType {
            self.sessionType = [sessionType]
        } else {
            self.sessionType = []
        }
    }
    
    init(sessionType: [String], groupBy: [String] = []) {
        self.groupBy = groupBy
        self.sessionType = sessionType
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            if sessionType.count > 1 {
                let fetched = try await F1PredictorSessionParser.fetchRacesWithLaps(year: 2026, sessionType: nil)
                sessions = makeGroups(
                    fetched
                        .filter { sessionType.contains($0.sessionType) }
                        .sortedByDate
                    )
            } else if !sessionType.isEmpty {
                let fetched = try await F1PredictorSessionParser.fetchRacesWithLaps(year: 2026, sessionType: sessionType[0])
                sessions = makeGroups(
                    fetched
                        .sortedByDate
                    )
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    private func makeGroups(_ sorted: [F1PredictorSession]) -> [MultiF1PredictorSession] {
        var result: [MultiF1PredictorSession] = []
        var indexForKey: [String: Int] = [:]

        for s in sorted {
            if groupBy.contains(s.sessionType) {
                let key = "\(s.meetingKey)-\(s.sessionType)"   // weekend + type
                if let i = indexForKey[key] {
                    result[i].sessions.append(s)
                } else {
                    indexForKey[key] = result.count
                    result.append(MultiF1PredictorSession(sessions: [s]))
                }
            } else {
                result.append(MultiF1PredictorSession(sessions: [s]))
            }
        }
        return result
    }
}
