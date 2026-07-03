//
//  LiveF1WidgetLiveActivity.swift
//  LiveF1Widget
//
//  Created by Riley Koo on 7/3/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LiveF1WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LiveF1WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveF1WidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension LiveF1WidgetAttributes {
    fileprivate static var preview: LiveF1WidgetAttributes {
        LiveF1WidgetAttributes(name: "World")
    }
}

extension LiveF1WidgetAttributes.ContentState {
    fileprivate static var smiley: LiveF1WidgetAttributes.ContentState {
        LiveF1WidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LiveF1WidgetAttributes.ContentState {
         LiveF1WidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LiveF1WidgetAttributes.preview) {
   LiveF1WidgetLiveActivity()
} contentStates: {
    LiveF1WidgetAttributes.ContentState.smiley
    LiveF1WidgetAttributes.ContentState.starEyes
}
