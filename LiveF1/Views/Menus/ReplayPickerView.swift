//
//  ReplayPickerView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI
import SafariServices
import Combine

// MARK: - Replay picker

struct ReplayPickerView: View {
    @ObservedObject var store: F1SessionStore
    @State private var sessions: [F1Session] = []
    @State private var isLoading = false
    @State private var replayClient: F1ReplayClient?

    var body: some View {
        ZStack {
            Group {
                if sessions.isEmpty {
                    Button("Load 2025 Sessions") {
                        Task { await loadSessions() }
                    }
                } else {
                    List(sessions) { session in
                        Button(session.name) {
                            startReplay(session)
                        }
                    }
                }
            }
            .navigationTitle("Pick a Session")
            VStack {
                Spacer()
                NavigationLink("View Timing →") {
                    TimingTowerView(store: store)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
    }

    private func loadSessions() async {
        isLoading = true
        let url = "https://livetiming.formula1.com/static/2025/Index.json"
        print("🔍 Fetching: \(url)")
        guard let urlObj = URL(string: url),
              let (data, resp) = try? await URLSession.shared.data(from: urlObj)
        else {
            print("❌ Request failed")
            isLoading = false
            return
        }
        print("✅ Got response: \((resp as? HTTPURLResponse)?.statusCode ?? -1), bytes: \(data.count)")
        print("📄 Raw: \(String(data: data.prefix(500), encoding: .utf8) ?? "unreadable")")
        sessions = await fetchSessions(year: 2025)
        isLoading = false
    }

    private func startReplay(_ session: F1Session) {
        print("▶ Starting replay at path: \(session.path)")
        store.clear()
        let client = F1ReplayClient()
        client.speed = 20.0
        store.dataSource = client
        replayClient = client
        client.start(sessionPath: session.path)
    }
}
