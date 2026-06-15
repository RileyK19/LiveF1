//
//  DebugTabView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI
import SafariServices
import Combine

// MARK: - Debug tabs

struct DebugTabView: View {
    @ObservedObject var store: F1SessionStore

    var body: some View {
        TabView {
            TopicListView(store: store)
                .tabItem { Label("Topics", systemImage: "list.bullet") }

            MessageLogView(store: store)
                .tabItem { Label("Log", systemImage: "scroll") }
        }
    }
}

// MARK: - Topic list (current merged state per topic)

struct TopicListView: View {
    @ObservedObject var store: F1SessionStore

    var sortedTopics: [(String, Any)] {
        store.rawTopics.sorted { $0.key < $1.key }
    }

    var body: some View {
        List(sortedTopics, id: \.0) { (topic, value) in
            NavigationLink(topic) {
                TopicDetailView(topic: topic, value: value)
            }
        }
        .navigationTitle("Topics (\(store.rawTopics.count))")
    }
}

struct TopicDetailView: View {
    let topic: String
    let value: Any

    var body: some View {
        ScrollView {
            Text(prettyPrint(value))
                .font(.system(.caption, design: .monospaced))
                .padding()
                .textSelection(.enabled)
        }
        .navigationTitle(topic)
    }

    private func prettyPrint(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8)
        else { return String(describing: value) }
        return str
    }
}

// MARK: - Message log (stream of incoming deltas)

struct MessageLogView: View {
    @ObservedObject var store: F1SessionStore

    var body: some View {
        List(store.messages.reversed().indices, id: \.self) { i in
            let msg = store.messages.reversed()[i]
            VStack(alignment: .leading, spacing: 2) {
                Text(msg.topic)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(oneLineJSON(msg.payload))
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(2)
            }
        }
        .navigationTitle("Message Log")
    }

    private func oneLineJSON(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8)
        else { return "" }
        return str
    }
}
