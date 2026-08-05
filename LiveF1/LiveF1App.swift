//
//  LiveF1App.swift
//  LiveF1
//
//  Created by Riley Koo on 6/4/26.
//

import SwiftUI
import NotificationLog

@main
struct LiveF1App: App {
    @State private var router = Router()
    var body: some Scene {
        WindowGroup {
//            ContentView()
//            HomeView()
//                .notificationLog(config: NotificationLogConfig(
//                    supabaseURL: Constants.supabaseURL,
//                    supabaseAnonKey: Constants.supabaseAnonKey,
//                    appID: Constants.appID
//                ))
            NavigationStack(path: $router.path) {
                HomeView()
                    .navigationDestination(for: Destination.self) {
                        DestinationView(destination: $0)
                    }
                    .notificationLog(config: NotificationLogConfig(
                        supabaseURL: Constants.supabaseURL,
                        supabaseAnonKey: Constants.supabaseAnonKey,
                        appID: Constants.appID
                    ))
            }
            .environment(router)
        }
    }
}
