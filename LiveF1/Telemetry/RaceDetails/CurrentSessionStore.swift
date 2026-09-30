//
//  CurrentSessionStore.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//


import Foundation
import Combine

@MainActor
final class CurrentSessionStore: ObservableObject, Hashable {
    @Published private(set) var raceViewModel: RaceViewModel?

    static func == (lhs: CurrentSessionStore, rhs: CurrentSessionStore) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    func load(session: F1PredictorSession) {
        if raceViewModel?.session.sessionKey == session.sessionKey { return }
        let vm = RaceViewModel(session: session)
        raceViewModel = vm
        Task { await vm.load() }
    }

    func clear() {
        raceViewModel = nil
    }
    
    func loadAndWait(session: F1PredictorSession) async -> RaceViewModel {
        print("existing:", raceViewModel?.session.sessionKey ?? -1, "new:", session.sessionKey)
        if let existing = raceViewModel, existing.session.sessionKey == session.sessionKey {
            return existing
        }
        let vm = RaceViewModel(session: session)
        raceViewModel = vm
        await vm.load()
        return vm
    }
    
    func printDrivers() {
        print(raceViewModel?.drivers)
    }
}
