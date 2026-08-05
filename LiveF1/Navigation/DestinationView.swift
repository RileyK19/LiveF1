//
//  DestinationView.swift
//  LiveF1
//
//  Created by Riley Koo on 8/4/26.
//


import SwiftUI

struct DestinationView: View {
    @Environment(Router.self) private var router

    let destination: Destination

    var body: some View {
        switch destination {
        case .liveConnect(let store):
            LiveConnectView(store: store)
        case .sessionPicker3(let title, let sessionType, let dest):
            switch dest {
            case SessionDestination.lapPicker:
                SessionPickerView(title: title, sessionType: sessionType, route: { session in
                    router.push(.lapPicker(session))
                })
            case SessionDestination.racePace:
                SessionPickerView(title: title, sessionType: sessionType, route: { session in
                    router.push(.racePace(session))
                })
            case SessionDestination.raceDetail:
                SessionPickerView(title: title, sessionType: sessionType, route: { session in
                    router.push(.raceDetail(session))
                })
            }
        case .lapPicker(let session):
            LapPickerView(session: session)
        case .sessionPicker2(let title, let dest):
            switch dest {
            case SessionDestination.lapPicker:
                SessionPickerView(title: title, route: { session in
                    router.push(.lapPicker(session))
                })
            case SessionDestination.racePace:
                SessionPickerView(title: title, route: { session in
                    router.push(.racePace(session))
                })
            case SessionDestination.raceDetail:
                SessionPickerView(title: title, route: { session in
                    router.push(.raceDetail(session))
                })
            }
        case .racePace(let session):
            RacePaceView(session: session)
        case .sessionPicker(let dest):
            switch dest {
            case SessionDestination.lapPicker:
                SessionPickerView(route: { session in
                    router.push(.lapPicker(session))
                })
            case SessionDestination.racePace:
                SessionPickerView(route: { session in
                    router.push(.racePace(session))
                })
            case SessionDestination.raceDetail:
                SessionPickerView(route: { session in
                    router.push(.raceDetail(session))
                })
            }
        case .raceDetail(let session):
            RaceDetailView(session: session)
        case .schedule(let store):
            ChampionshipScheduleView()
                .environment(store)
        case .standings(let store):
            ChampionshipStandingsView()
                .environment(store)
        case .weather(let store):
            WeatherView()
                .environment(store)
        case .debug(let store):
            DebugTabView(store: store)
        case .credits:
            CreditsView()
        case .raceStory(let round, let id, let store):
            RaceStoryView(selectedRound: round, selectedDriverId: id)
                .environment(store)
        case .fiaDoc(let document):
            FIADocumentDetailView(document: document)
        case .fiaDocList:
            FIADocumentsView()
        case .timingTower(let store):
            TimingTowerView(store: store)
                .overlay(ToastContainerView(store: store))
        case .trackMap(let store, let VM):
            TrackMapView(store: store, VM: VM)
        case .eventLog(let store):
            EventLogView(store: store)
        case .speedTrace(let session, let laps):
            SpeedTraceView(session: session, laps: laps)
        case .assistant2(let VM, let tab):
            StrategyAssistantView(viewModel: VM, selectedTab: tab)
        case .assistant(let VM):
            StrategyAssistantView(viewModel: VM)
        }
    }
}
