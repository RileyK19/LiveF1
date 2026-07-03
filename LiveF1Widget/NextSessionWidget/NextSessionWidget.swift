//
//  NextSessionWidget.swift
//  LiveF1
//
//  Created by Riley Koo on 7/3/26.
//


import WidgetKit
import SwiftUI

struct NextSessionWidgetContent: View {
    @Environment(\.widgetFamily) var family
    let entry: NextSessionEntry

    var body: some View {
        switch family {
        case .systemSmall:
            NextSessionSmallView(entry: entry)
        case .systemMedium:
            NextRaceSessionsView(entry: entry)
        case .accessoryCircular:
            NextSessionCircularView(entry: entry)
        case .accessoryRectangular:
            NextSessionRectangularView(entry: entry)
        case .accessoryInline:
            NextSessionInlineView(entry: entry)
        default:
            NextSessionSmallView(entry: entry)
        }
    }
}

struct NextSessionWidget: Widget {
    let kind = "NextSessionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextSessionProvider()) { entry in
            NextSessionWidgetContent(entry: entry)
                .containerBackground(.regularMaterial, for: .widget)
        }
        .configurationDisplayName("Next F1 Session")
        .description("Countdown to the next session and race schedule.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}
