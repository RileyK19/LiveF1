//
//  AssistantCardContent.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//
//

import Foundation

enum AssistantCardContent {
    case strategy(
        driverNumber: Int,
        driverName: String,
        actual: [F1PredictorStint],
        hypothetical: [F1PredictorStint],
        timeDelta: Double?
    )
    case standings(GetDriverStandingsResult)
    case constructorStandings(GetConstructorStandingsResult)
    case schedule(GetScheduleResult)
    case raceResults(GetRaceResultsResult)
    case sessionPicker(options: [SessionOption], coordinator: SessionSelectionCoordinator)
    case racePace(focusedStats: [DriverPaceStats], allStats: [DriverPaceStats], result: GetRacePaceResult)
    case fiaDocuments(documents: [FIADocumentInfo], result: GetFIADocumentsResult)
    case laps(laps: [LapSummary], result: GetLapsResult)
}


struct AssistantMessage: Identifiable {
    let id = UUID().uuidString
    let role: Role
    let content: Content

    enum Role {
        case user
        case assistant
    }

    enum Content {
        case text(String)
        case card(AssistantCardContent)
    }

    init(role: Role, text: String) {
        self.role = role
        self.content = .text(text)
    }

    init(role: Role, card: AssistantCardContent) {
        self.role = role
        self.content = .card(card)
    }
}

//import Foundation
//
//enum AssistantCardContent {
//    case strategy(actual: [F1PredictorStint], hypothetical: [F1PredictorStint], timeDelta: Double?)
//    case standings(GetDriverStandingsResult)
//    case constructorStandings(GetConstructorStandingsResult)
//    case schedule(GetScheduleResult)
//    case raceResults(GetRaceResultsResult)
//    case sessionPicker(options: [SessionOption], coordinator: SessionSelectionCoordinator)
//}
//
//struct AssistantMessage: Identifiable {
//    let id = UUID().uuidString
//    let role: Role
//    let content: Content
//
//    enum Role {
//        case user
//        case assistant
//    }
//
//    enum Content {
//        case text(String)
//        case card(AssistantCardContent)
//    }
//
//    init(role: Role, text: String) {
//        self.role = role
//        self.content = .text(text)
//    }
//
//    init(role: Role, card: AssistantCardContent) {
//        self.role = role
//        self.content = .card(card)
//    }
//}
