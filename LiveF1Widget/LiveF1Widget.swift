////
////  LiveF1Widget.swift
////  LiveF1Widget
////
////  Created by Riley Koo on 7/3/26.
////
//
//import WidgetKit
//import SwiftUI
//
//struct NextSessionWidget: Widget {
//    let kind = "NextSessionWidget"
//
//    var body: some WidgetConfiguration {
//        StaticConfiguration(kind: kind, provider: NextSessionProvider()) { entry in
//            if #available(iOS 17.0, *) {
//                NextSessionWidgetContent(entry: entry)
//                    .containerBackground(.regularMaterial, for: .widget)
//            } else {
//                NextSessionWidgetContent(entry: entry)
//                    .padding()
//                    .background(.regularMaterial)
//            }
//        }
//        .configurationDisplayName("Next F1 Session")
//        .description("Countdown to the next session and race schedule.")
//        .supportedFamilies([.systemSmall, .systemMedium])
//    }
//}
//
//struct NextSessionWidgetContent: View {
//    @Environment(\.widgetFamily) var family
//    let entry: NextSessionEntry
//
//    var body: some View {
//        switch family {
//        case .systemSmall:
//            NextSessionSmallView(entry: entry)
//        default:
//            NextRaceSessionsView(entry: entry)
//        }
//    }
//}
//
//struct LiveF1Widget: Widget {
//    let kind: String = "LiveF1Widget"
//
//    var body: some WidgetConfiguration {
//        StaticConfiguration(kind: kind, provider: Provider()) { entry in
//            if #available(iOS 17.0, *) {
//                LiveF1WidgetEntryView(entry: entry)
//                    .containerBackground(.fill.tertiary, for: .widget)
//            } else {
//                LiveF1WidgetEntryView(entry: entry)
//                    .padding()
//                    .background()
//            }
//        }
//        .configurationDisplayName("My Widget")
//        .description("This is an example widget.")
//    }
//}
//
//#Preview(as: .systemSmall) {
//    LiveF1Widget()
//} timeline: {
//    SimpleEntry(date: .now, emoji: "😀")
//    SimpleEntry(date: .now, emoji: "🤩")
//}
