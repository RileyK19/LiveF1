//
//  MultiRaceViewModel.swift
//  Redline
//
//  Created by Riley Koo on 10/27/26.
//

import Foundation
import Combine

@MainActor
class MultiRaceViewModel: ObservableObject, Equatable, Hashable {
    var sessions: [F1PredictorSession]
    var wrapped: [RaceViewModel]
    
    public var id: UUID = UUID()

    @Published var laps: [F1Lap] = []
    @Published var stints: [F1PredictorStint] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    static func == (lhs: MultiRaceViewModel, rhs: MultiRaceViewModel) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    init(session: F1PredictorSession) {
        self.sessions = [session]
        self.wrapped = [RaceViewModel(session: session)]
    }
    
    init(sessions: [F1PredictorSession]) {
        self.sessions = []
        self.wrapped = []
        for s in sessions {
            self.sessions.append(s)
            self.wrapped.append(RaceViewModel(session: s))
        }
    }

    func load() async {
        await withTaskGroup { group in
            for VM in wrapped {
                group.addTask {
                    await VM.load()
                }
            }
        }
    }

    var drivers: [Int] {
        wrapped.flatMap { $0.drivers }
    }
    
    func annotatedLaps(for driver: Int) -> [AnnotatedLap] {
        return wrapped.flatMap { $0.annotatedLaps(for: driver) }
    }
}
