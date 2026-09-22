//
//  Destination.swift
//  LiveF1
//
//  Created by Riley Koo on 8/4/26.
//

import Foundation

enum Destination: Hashable {
    case liveConnect(F1SessionStore)
//    case liveConnect(F1SessionStore, F1TimingClient)
    case sessionPicker3(String, String?, SessionDestination)
    case sessionPicker2(String, SessionDestination)
    case sessionPicker(SessionDestination)
    case sessionPickerVmEnv(SessionDestination, CurrentSessionStore)
    case lapPicker(F1PredictorSession)
    case racePace(F1PredictorSession)
    case raceDetail(F1PredictorSession)
    case raceDetailVmEnv(F1PredictorSession, CurrentSessionStore)
    case schedule(ChampionshipDataStore)
    case standings(ChampionshipDataStore)
    case weather(ChampionshipDataStore)
    case debug(F1SessionStore)
    case credits
    case raceStory(String?, String?, ChampionshipDataStore)
    case fiaDoc(FIADocument)
    case fiaDocList(FIADocumentStore)
    case timingTower(F1SessionStore)
    case trackMap(F1SessionStore, TrackMapViewModel)
    case eventLog(F1SessionStore)
    case speedTrace(F1PredictorSession, [F1Lap])
    case assistant2(RaceViewModel, String)
    case assistant(RaceViewModel)
    case lapReplay(F1PredictorSession, [F1Lap])
    case replayLapPicker(F1PredictorSession)
    case appAssistant(CurrentSessionStore, ChampionshipDataStore, FIADocumentStore)
}

enum SessionDestination: Hashable {
    case lapPicker
    case racePace
    case raceDetail
    case replayLapPicker
}
