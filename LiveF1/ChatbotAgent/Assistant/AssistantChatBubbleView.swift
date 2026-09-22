//
//  AssistantChatBubbleView.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//

import SwiftUI

struct AssistantChatBubbleView: View {
    let message: AssistantMessage
    var viewModel: RaceViewModel?

    var body: some View {
        switch message.content {
        case .text(let text):
            HStack {
                if message.role == .user { Spacer() }
                Text(text)
                    .font(.subheadline)
                    .padding(12)
                    .background(message.role == .user ? Color.red.opacity(0.8) : Color.secondary.opacity(0.1))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
                if message.role == .assistant { Spacer() }
            }

        case .card(let card):
            switch card {
            case .strategy(let driverNumber, let driverName, let actual, let hypothetical, let timeDelta):
                if let viewModel {
                    StrategyResultCard(
                        driverNumber: driverNumber,
                        driverName: driverName,
                        actual: actual,
                        hypothetical: hypothetical,
                        timeDelta: timeDelta,
                        viewModel: viewModel
                    )
                }
            case .standings(let result):
                StandingsCardView(result: result)
            case .constructorStandings(let result):
                ConstructorStandingsCardView(result: result)
            case .schedule(let result):
                ScheduleCardView(result: result)
            case .raceResults(let result):
                RaceResultsCardView(result: result)
            case .sessionPicker(let options, let coordinator):
                SessionPickerCardView(options: options, coordinator: coordinator)
            case .racePace(let focusedStats, let allStats, let result):
                RacePaceCardView(focusedStats: focusedStats, allStats: allStats, result: result)
            case .fiaDocuments(let documents, let result):
                FIADocumentCardView(documents: documents, result: result)
            case .laps(let laps, let result):
                LapsCardView(laps: laps, result: result)
            }
        }
    }
}

//
//import SwiftUI
//
//struct AssistantChatBubbleView: View {
//    let message: AssistantMessage
//    var viewModel: RaceViewModel?
//    
//    var body: some View {
//        switch message.content {
//        case .text(let text):
//            HStack {
//                if message.role == .user { Spacer() }
//                Text(text)
//                    .font(.subheadline)
//                    .padding(12)
//                    .background(message.role == .user ? Color.red.opacity(0.8) : Color.secondary.opacity(0.1))
//                    .foregroundStyle(message.role == .user ? .white : .primary)
//                    .clipShape(RoundedRectangle(cornerRadius: 16))
//                    .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
//                if message.role == .assistant { Spacer() }
//            }
//
//        case .card(let card):
//            switch card {
//            case .strategy(let actual, let hypothetical, let timeDelta):
//                if let viewModel {
//                    StrategyResultCard(actual: actual, hypothetical: hypothetical, timeDelta: timeDelta, viewModel: viewModel)
//                }
//            case .standings(let result):
//                StandingsCardView(result: result)
//            case .constructorStandings(let result):
//                ConstructorStandingsCardView(result: result)
//            case .schedule(let result):
//                ScheduleCardView(result: result)
//            case .raceResults(let result):
//                RaceResultsCardView(result: result)
//            case .sessionPicker(let options, let coordinator):
//                SessionPickerCardView(options: options, coordinator: coordinator)
//            }
//        }
//    }
//}
