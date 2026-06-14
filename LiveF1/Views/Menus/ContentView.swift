//
//  ContentView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/4/26.
//

import SwiftUI
import SafariServices
import Combine
import WebKit
import NotificationLog

struct ContentView: View {
    @StateObject private var store = F1SessionStore()
    @State private var mode: AppMode = .live
    @AppStorage("isDark") private var isDark = false
    @State private var showingSettings = false

    enum AppMode { case live, replay, documents }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .replay: ReplayPickerView(store: store)
                case .live:   LiveConnectView(store: store)
                case .documents: FIADocumentsView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    FeedbackButton()
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(mode: $mode, store: store)
            }
        }
        .preferredColorScheme(isDark ? .dark : .light)
    }
}
