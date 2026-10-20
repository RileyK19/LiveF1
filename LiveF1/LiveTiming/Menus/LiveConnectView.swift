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
//    @StateObject var trackerVM: TrackMapViewModel = TrackMapViewModel()
    @State private var token: String = ""
    @State var liveClient: F1TimingClient?
//    @ObservedObject var liveClient: F1TimingClient
    @State private var replayClient: F1ReplayClient?
    @State private var replaySession: F1Session?
    @State private var showingBrowser = false
    @State private var hasSavedToken = TokenStore.load() != nil
    @State private var delay: Int = 0
    @State private var showingInfo = false
    @FocusState private var focus: Bool
    private var liveActivityToggle: Bool { LiveActivityManager.liveActivityToggle }
    var statusText: String {
        switch store.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting:   return "Connecting..."
        case .connected:    return "Connected"
        case .error(let e): return "Error: \(e)"
        }
    }

    var body: some View {
        ScrollView {
//            VStack(spacing: 16) {
            VStack(spacing: 20) {
                HStack(spacing: 14) {
//                    NavigationLink {
//                        TimingTowerView(store: store)
//                            .overlay(ToastContainerView(store: store))
//                    } label: {
                    NavigationLink(value: Destination.timingTower(store)) {
                        SquircleCard(icon: "stopwatch", title: "Timing Tower", subtitle: "Live driver timing data", color: .red)
                    }
                    .buttonStyle(.plain)
                    
//                    NavigationLink { TrackMapView(store: store, VM: trackerVM) } label: {
//                    NavigationLink(value: Destination.trackMap(store, trackerVM)) {
                    NavigationLink(value: Destination.trackMap(store, store.trackMapVM)) {
                        SquircleCard(icon: "map", title: "Driver Tracker", subtitle: "Track map of driver positions", color: .orange)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                
//                NavigationLink {
//                    EventLogView(store: store)
//                } label: {
                NavigationLink(value: Destination.eventLog(store)) {
                    RowCard(
                        icon: "megaphone",
                        title: "Race Control",
                        subtitle: "See race control messages",
                        color: .yellow
                    )
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
                
//                ConnectionRowCard(icon: "key", value: $token, title: "(Opt) F1TV Login", titleKey: token.isEmpty ? "Not logged in" : "Logged in", color: .blue, onPress: {
//                    if token.isEmpty {
//                        showingBrowser = true
//                    } else {
//                        TokenStore.clear()
//                        token = ""
//                        hasSavedToken = false
//                    }
//                }, buttonTitle: token.isEmpty ? "Sign In" : "Log Out", onPressInfo: {
//                    showingInfo = true
//                })
//                .buttonStyle(.plain)
//                .padding(.horizontal, 20)
                
                if !token.isEmpty {
                    ReplayRowCard(selected: replaySession, onSelect: startReplay, onExit: connect)
                        .equatable()
                        .padding(.horizontal, 20)
                }
                
                RowCard(icon: "key", color: .blue) {
                    HStack(spacing: 12) {
                        Button {
                            showingInfo = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(Color.blue.opacity(0.8))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("(Opt) F1TV Login")
                                .font(.system(size: 10))
                                .foregroundStyle(.primary)
                            Text(token.isEmpty ? "Not logged in" : "Logged in")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                } trailing: {
                    PillButton(title: token.isEmpty ? "Sign In" : "Log Out", color: .blue) {
                        if token.isEmpty {
                            showingBrowser = true
                        } else {
                            TokenStore.clear()
                            token = ""
                            hasSavedToken = false
                        }
                    }
                }
                .padding(.horizontal, 20)
                
//                DelayRowCard(icon: "clock", value: $delay, titleKey: "Enter delay amount", color: .purple, onPress: {
//                    store.setDelay(TimeInterval(delay))
//                    focus = false
//                }, buttonTitle: "Set delay", focus: $focus)
//                .buttonStyle(.plain)
//                .padding(.horizontal, 20)
                RowCard(icon: "clock", color: .purple) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enter delay amount")
                            .font(.system(size: 10))
                            .foregroundStyle(.primary)
                        TextField("Enter delay amount", value: $delay, format: .number)
                            .keyboardType(.numberPad)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.purple)
                            .focused($focus)
                    }
                } trailing: {
                    PillButton(title: "Set delay", color: .purple) {
                        store.setDelay(TimeInterval(delay))
                        focus = false
                    }
                }
                .padding(.horizontal, 20)
                
                RowCard(icon: "bell", color: .orange) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lock screen live updates")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                } trailing: {
                    PillButton(title: liveActivityToggle ? "Disable" : "Enable", color: .orange) {
                        LiveActivityManager.liveActivityToggle.toggle()
                    }
                }
                .padding(.horizontal, 20)
                
//                ReconnectRowCard(icon: "arrow.counterclockwise.circle", value: statusText,
//                                 titleKey: "Connection Status",
//                                 color: statusText == "Connected" ? .green : statusText == "Disconnected" ? .red : .orange,
//                                 onPress: {
//                    connect()
//                    trackerVM.reset()
//                }, buttonTitle: "Reconnect")
//                .buttonStyle(.plain)
//                .padding(.horizontal, 20)
                RowCard(icon: "arrow.counterclockwise.circle", color: statusText == "Connected" ? .green : statusText == "Disconnected" ? .red : .orange) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connection Status")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(statusText)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                } trailing: {
                    PillButton(title: "Reconnect", color: statusText == "Connected" ? .green : statusText == "Disconnected" ? .red : .orange) {
                        connect()
//                        trackerVM.reset()
                        store.trackMapVM.reset()
                    }
                }
                .padding(.horizontal, 20)

            }
            .onTapGesture {
                focus = false
            }
            
//            Text("Sign in to F1TV for telemetry")
//                .font(.caption)
//                .foregroundStyle(.secondary)
//                .multilineTextAlignment(.center)
//
//            Button("Open F1TV in Browser") {
//                showingBrowser = true
//            }
//            .buttonStyle(.bordered)
//
//            HStack {
//                SecureField("SubscriptionToken will autofill here", text: $token)
//                    .textFieldStyle(.roundedBorder)
//                    .lineLimit(4)
//                if hasSavedToken {
//                    Button("Clear Token", role: .destructive) {
//                        TokenStore.clear()
//                        token = ""
//                        hasSavedToken = false
//                    }
//                }            }
//
//            if token.isEmpty {
//                Button("Connect (no login)") {
//                    store.clear()
//                    let client = F1TimingClient()
//                    store.dataSource = client
//                    liveClient = client
//                    Task { await client.connect(token: nil) }
//                }
//                .buttonStyle(.bordered)
//            } else {
//                Button("Connect") {
//                    connect()
//                }
//                .disabled(token.isEmpty)
//                .buttonStyle(.borderedProminent)
//            }
//            
//            Text(statusText)
//                .font(.caption)
//                .foregroundStyle(.secondary)
//            
//            Button(store.delaySeconds == 0 ? "LIVE" : "-\(Int(store.delaySeconds))s (tap for live)") {
//                store.setDelay(store.delaySeconds == 0 ? 30 : 0)
//            }
//            .buttonStyle(.bordered)
//            .tint(store.delaySeconds == 0 ? .green : .orange)
//
//            if store.rawTopics.isEmpty == false {
//                NavigationLink("View Timing Tower →") {
//                    TimingTowerView(store: store)
//                }
//                .buttonStyle(.borderedProminent)
//                
//                NavigationLink("View Driver Tracker →") {
//                    TrackMapView(store: store)
//                }
//                .buttonStyle(.borderedProminent)
//                if token.isEmpty {
//                    Text("Note: driver tracker may not work without F1TV")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                        .multilineTextAlignment(.center)
//                }
//            }
        }
//        .padding()
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
            
            if replayClient == nil { connect() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guard liveClient != nil else { return }
            connect()
//            let client = F1TimingClient()
//            store.dataSource = client
//            liveClient = client
//            Task { await client.connect(token: liveClient?.currentToken) }
//            Task { await liveClient.connect(token: liveClient.currentToken) }
        }
        .alert("(Optional) F1 TV Login", isPresented: $showingInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Sign into F1 TV to access extra live telemetry and driver tracker data. F1 TV gives access to throttle, brake, gear, and tracker data, but live timing still works without F1 TV.")
        }
    }

    private func connect() {
        teardownReplay()
        detachLive()
        store.trackMapVM.reset()
        store.reset()
        let client = F1TimingClient()
        store.dataSource = client
        liveClient = client
        Task { await client.connect(token: token) }
//        Task { await liveClient.connect(token: token) }
    }
    
    private func startReplay(_ session: F1Session) {
        detachLive()
        teardownReplay()
        store.clear()
        store.reset()
        store.trackMapVM.reset()
        let client = F1ReplayClient()
        client.pacing = .realtime(speed: 10)   // or .unpaced for benchmarking
        store.dataSource = client
        replayClient = client
        replaySession = session
        client.start(sessionPath: session.path)
    }

    private func teardownReplay() {
        replayClient?.onMessage = nil
        replayClient?.onStateChange = nil
        replayClient?.stop()
        replayClient = nil
        replaySession = nil
    }

    private func detachLive() {
        liveClient?.onMessage = nil
        liveClient?.onStateChange = nil
        liveClient?.disconnect()
        liveClient = nil
    }
}

struct ReplayRowCard: View, Equatable {
    let selected: F1Session?                  // nil = live
    let onSelect: (F1Session) -> Void
    let onExit: () -> Void

    // Closures are ignored: only a change of selection should rebuild the card.
    static func == (lhs: ReplayRowCard, rhs: ReplayRowCard) -> Bool {
        lhs.selected?.id == rhs.selected?.id
    }

    private struct MeetingGroup: Identifiable {
        let id: String
        let name: String
        var sessions: [(session: F1Session, label: String)]
        var sessionIDs: [String] { sessions.map(\.session.id) }
    }

    private struct YearGroup: Identifiable {
        let year: Int
        var meetings: [MeetingGroup]
        var id: Int { year }
    }

    @State private var yearGroups: [YearGroup] = []
    @State private var isLoading = false

    private let years = [2026, 2025]
    private let tint = Color.teal

    var body: some View {
        RowCard(icon: "play.circle", color: tint) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Replay a race")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary)
                Text(selected?.name ?? "Live")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(tint)
                    .lineLimit(1)
            }
        } trailing: {
            HStack(spacing: 8) {
                if yearGroups.isEmpty {
                    // Nothing loaded: either still loading or the fetch failed.
                    Button {
                        Task { await loadSessions() }
                    } label: {
                        pill(isLoading ? "Loading…" : "Retry")
                    }
                    .disabled(isLoading)
                } else {
                    Menu {
                        ForEach(yearGroups) { yg in
                            Section(String(yg.year)) {
                                ForEach(yg.meetings) { meeting in
                                    Menu(meeting.name) {
                                        ForEach(meeting.sessions, id: \.session.id) { item in
                                            Button(item.label) { onSelect(item.session) }
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        pill("Choose")
                    }
                }

                if selected != nil {
                    Button(action: onExit) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Return to live")
                }
            }
        }
        .onAppear { Task { await loadSessions() } }
    }

    private func pill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tint.opacity(0.15), in: Capsule())
    }

    // Fetch each year in parallel, then group once (not on every render).
    private func loadSessions() async {
        guard yearGroups.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let fetched = await withTaskGroup(of: (Int, [F1Session]).self) { group in
            for year in years {
                group.addTask { (year, await fetchSessions(year: year)) }
            }
            var out: [Int: [F1Session]] = [:]
            for await (year, sessions) in group { out[year] = sessions }
            return out
        }

        var result: [YearGroup] = []
        for year in years {
            guard let sessions = fetched[year], !sessions.isEmpty else { continue }
            var meetings: [MeetingGroup] = []
            for s in sessions {
                let parts = s.name.components(separatedBy: " — ")
                let meeting = parts.first ?? s.name
                let label = parts.last ?? s.name
                let key = "\(year)-\(meeting)"
                if let i = meetings.firstIndex(where: { $0.id == key }) {
                    meetings[i].sessions.append((s, label))
                } else {
                    meetings.append(MeetingGroup(id: key, name: meeting, sessions: [(s, label)]))
                }
            }
            result.append(YearGroup(year: year, meetings: meetings))
        }
        yearGroups = result
    }
}
