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
            
            PrintLogView()
                .tabItem { Label("Print", systemImage: "printer") }
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
            
            Menu {
                Button {
                    UIPasteboard.general.string = "\(msg.topic): \(oneLineJSON(msg.payload))"
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(msg.topic)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(oneLineJSON(msg.payload))
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(2)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func oneLineJSON(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8)
        else { return "" }
        return str
    }
}

struct PrintLogView: View {
    @State private var filterWord = ""

    private var filteredLogs: [String] {
        PrintLog.log.reversed().filter { msg in
            filterWord.isEmpty ||
            msg.localizedCaseInsensitiveContains(filterWord)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search logs...", text: $filterWord)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !filterWord.isEmpty {
                    Button {
                        filterWord = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.vertical, 8)

            List {
                Button(role: .destructive) {
                    PrintLog.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .foregroundStyle(.red)
                }

                ForEach(filteredLogs.indices, id: \.self) { i in
                    let msg = filteredLogs[i]

                    Menu {
                        Button {
                            UIPasteboard.general.string = msg
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(msg)
                                .font(.system(.caption2, design: .monospaced))
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
