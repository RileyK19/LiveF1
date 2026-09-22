//
//  F1LiveActivityWidget.swift
//  Redline
//
//  Created by Riley Koo on 9/19/26.
//


import ActivityKit
import WidgetKit
import SwiftUI

struct F1LiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: F1SessionAttributes.self) { context in
            // Lock screen / banner UI
            LockScreenLiveActivityView(state: context.state, sessionName: context.attributes.sessionName)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.leaderTLA)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.leaderGap)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Lap \(context.state.lapCount)")
                }
            } compactLeading: {
                Text(context.state.leaderTLA)
            } compactTrailing: {
                Text(context.state.p2TLA)
            } minimal: {
                Text(context.state.leaderTLA)
            }
        }
    }
}