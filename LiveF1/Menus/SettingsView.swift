//
//  SettingsView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI
import SafariServices
import Combine

struct SettingsView: View {
//    @Binding var mode: ContentView.AppMode
    @AppStorage("isDark") var isDark = true
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: F1SessionStore

    var body: some View {
        NavigationStack {
            Form {
//                Section("Data Source") {
//                    Picker("Mode", selection: $mode) {
//                        Text("Live").tag(ContentView.AppMode.live)
//                        Text("Replay").tag(ContentView.AppMode.replay)
//                        Text("Documents").tag(ContentView.AppMode.documents)
//                        Text("Predictor").tag(ContentView.AppMode.predictor)
//                    }
//                    .pickerStyle(.segmented)
//                }
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $isDark)
                }
                Section("Developer") {
                    NavigationLink {
                        DebugTabView(store: store)
                    } label: {
//                    NavigationLink(value: Destination.debug(store)) {
                        Label("Debug", systemImage: "ladybug")
                    }
                }
                Section("Credits") {
                    NavigationLink {
                        CreditsView()
                    } label: {
//                    NavigationLink(value: Destination.credits) {
                        Label("Credits", systemImage: "person.2.fill")
                    }
                }
                Section("Privacy") {
                    Link(destination: URL(string: "https://verdant-gaura-e8e.notion.site/Privacy-Policy-3afaa40c994480b09b42cb7ad12dbfa0?source=copy_link")!, label: {
                            Text("Privacy Policy")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    )
                }
                Section("Contact") {
                    Link("Email me", destination: URL(string: "mailto:rileykoo19@gmail.com")!)
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
