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
    @StateObject var trackerVM: TrackMapViewModel = TrackMapViewModel()
    @State private var token: String = ""
    @State private var liveClient: F1TimingClient?
    @State private var showingBrowser = false
    @State private var hasSavedToken = TokenStore.load() != nil
    @State private var delay: Int = 0
    @State private var showingInfo = false
    @FocusState private var focus: Bool
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
                    NavigationLink(value: Destination.trackMap(store, trackerVM)) {
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
                        trackerVM.reset()
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
            
            connect()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guard liveClient != nil else { return }
            let client = F1TimingClient()
            store.dataSource = client
            liveClient = client
            Task { await client.connect(token: liveClient?.currentToken) }
        }
        .alert("(Optional) F1 TV Login", isPresented: $showingInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Sign into F1 TV to access extra live telemetry and driver tracker data. F1 TV gives access to throttle, brake, gear, and tracker data, but live timing still works without F1 TV.")
        }
    }

    private func connect() {
        let client = F1TimingClient()
        store.dataSource = client
        liveClient = client
        Task { await client.connect(token: token) }
    }
}

//private struct ConnectionRowCard: View {
//    let icon: String
//    @State var value: Binding<String>
//    let title: String
//    let titleKey: String
//    let color: Color
//    var onPress: ()->Void
//    let buttonTitle: String
//    var onPressInfo: ()->Void
//
//    var body: some View {
//        HStack(spacing: 16) {
//            IconBadge(icon: icon, color: color, size: 48, iconSize: 20, cornerRadius: 14)
//            
//            Button {
//                onPressInfo()
//            } label: {
//                Image(systemName: "questionmark.circle")
//                    .foregroundColor(color.opacity(0.8))
//            }
//
//            VStack(alignment: .leading, spacing: 2) {
//                Text(title)
//                    .font(.system(size: 10))
//                    .foregroundStyle(.primary)
////                SecureField(titleKey, text: value)
//                Text(titleKey)
//                    .font(.system(size: 13, weight: .black, design: .rounded))
//                    .foregroundStyle(.secondary)
//                    .foregroundColor(color)
//            }
//
//            Spacer()
//            
//            Button {
//                onPress()
//            } label: {
//                Text(buttonTitle)
//                    .font(.system(size: 13, weight: .black, design: .rounded))
//                    .foregroundStyle(.secondary)
//                    .padding()
//            }
//            .overlay(
//                RoundedRectangle(cornerRadius: 24, style: .continuous)
//                    .strokeBorder(color.opacity(0.5), lineWidth: 2.5)
//            )
//        }
//        .padding(.horizontal, 20)
//        .padding(.vertical, 16)
//        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
//        .overlay(
//            RoundedRectangle(cornerRadius: 24, style: .continuous)
//                .strokeBorder(color.opacity(0.12), lineWidth: 1)
//        )
//    }
//}
//
//private struct DelayRowCard: View {
//    let icon: String
//    @State var value: Binding<Int>
//    let titleKey: String
//    let color: Color
//    var onPress: ()->Void
//    let buttonTitle: String
//    var focus: FocusState<Bool>.Binding
//
//    var body: some View {
//        HStack(spacing: 16) {
//            IconBadge(icon: icon, color: color, size: 48, iconSize: 20, cornerRadius: 14)
//
//            VStack(alignment: .leading, spacing: 2) {
//                Text(titleKey)
//                    .font(.system(size: 10))
//                    .foregroundStyle(.primary)
//                
//                TextField(titleKey, value: value, format: .number)
//                    .keyboardType(.numberPad)
//                    .font(.system(size: 13, weight: .black, design: .rounded))
//                    .foregroundStyle(.secondary)
//                    .foregroundColor(color)
//                    .focused(focus)
//            }
//            Spacer()
//            
//            Button {
//                onPress()
//            } label: {
//                Text(buttonTitle)
//                    .font(.system(size: 13, weight: .black, design: .rounded))
//                    .foregroundStyle(.secondary)
//                    .padding()
//            }
//            .overlay(
//                RoundedRectangle(cornerRadius: 24, style: .continuous)
//                    .strokeBorder(color.opacity(0.5), lineWidth: 2.5)
//            )
//        }
//        .padding(.horizontal, 20)
//        .padding(.vertical, 16)
//        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
//        .overlay(
//            RoundedRectangle(cornerRadius: 24, style: .continuous)
//                .strokeBorder(color.opacity(0.12), lineWidth: 1)
//        )
//    }
//}
//
//private struct ReconnectRowCard: View {
//    let icon: String
//    var value: String
//    let titleKey: String
//    let color: Color
//    var onPress: ()->Void
//    let buttonTitle: String
//
//    var body: some View {
//        HStack(spacing: 16) {
//            IconBadge(icon: icon, color: color, size: 48, iconSize: 20, cornerRadius: 14)
//
//            VStack(alignment: .leading, spacing: 2) {
//                Text(titleKey)
//                    .font(.system(size: 13, weight: .black, design: .rounded))
//                    .foregroundStyle(.primary)
//                
//                Text(value)
//                    .font(.system(size: 13))
//                    .foregroundStyle(.secondary)
//            }
//            Spacer()
//            
//            Button {
//                onPress()
//            } label: {
//                Text(buttonTitle)
//                    .font(.system(size: 13, weight: .black, design: .rounded))
//                    .foregroundStyle(.secondary)
//                    .padding()
//            }
//            .overlay(
//                RoundedRectangle(cornerRadius: 24, style: .continuous)
//                    .strokeBorder(color.opacity(0.5), lineWidth: 2.5)
//            )
//        }
//        .padding(.horizontal, 20)
//        .padding(.vertical, 16)
//        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
//        .overlay(
//            RoundedRectangle(cornerRadius: 24, style: .continuous)
//                .strokeBorder(color.opacity(0.12), lineWidth: 1)
//        )
//    }
//}
