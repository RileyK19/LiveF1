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
    var body: some Scene {
        WindowGroup {
//            ContentView()
            HomeView()
                .notificationLog(config: NotificationLogConfig(
                    supabaseURL: Constants.supabaseURL,
                    supabaseAnonKey: Constants.supabaseAnonKey,
                    appID: Constants.appID
                ))
        }
    }
}
