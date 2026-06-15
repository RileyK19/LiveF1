//
//  LiveConnectView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI
import SafariServices
import Combine

// MARK: - Live connect

struct LiveConnectView: View {
    @ObservedObject var store: F1SessionStore
    @State private var token: String = ""
    @State private var liveClient: F1TimingClient?
    @State private var showingBrowser = false
    @State private var hasSavedToken = TokenStore.load() != nil
    var statusText: String {
        switch store.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting:   return "Connecting..."
        case .connected:    return "Connected"
        case .error(let e): return "Error: \(e)"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Sign in to F1TV for telemetry")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open F1TV in Browser") {
                showingBrowser = true
            }
            .buttonStyle(.bordered)

            HStack {
                SecureField("SubscriptionToken will autofill here", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4)
                if hasSavedToken {
                    Button("Clear Token", role: .destructive) {
                        TokenStore.clear()
                        token = ""
                        hasSavedToken = false
                    }
                }            }

            if token.isEmpty {
                Button("Connect (no login)") {
                    store.clear()
                    let client = F1TimingClient()
                    store.dataSource = client
                    liveClient = client
                    Task { await client.connect(token: nil) }
                }
                .buttonStyle(.bordered)
            } else {
                Button("Connect") {
                    connect()
                }
                .disabled(token.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.rawTopics.isEmpty == false {
                NavigationLink("View Timing →") {
                    TimingTowerView(store: store)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationTitle("Live Connection")
        .sheet(isPresented: $showingBrowser) {
            F1LoginWebView { t in
                self.token = t
                TokenStore.save(t)
                hasSavedToken = true
                showingBrowser = false
            }
        }
        .onAppear {
            store.requestSpeechPermission()
            if let saved = TokenStore.load() {
                token = saved
            }
            
            connect()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guard liveClient != nil else { return }
            let client = F1TimingClient()
            store.dataSource = client
            liveClient = client
            Task { await client.connect(token: liveClient?.currentToken) }
        }
    }

    private func connect() {
        let client = F1TimingClient()
        store.dataSource = client
        liveClient = client
        Task { await client.connect(token: token) }
    }
}
