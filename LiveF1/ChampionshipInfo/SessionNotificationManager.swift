//
//  SessionNotificationManager.swift
//  LiveF1
//
//  Created by Riley Koo on 7/25/26.
//


import UserNotifications

final class SessionNotificationManager {
    static let shared = SessionNotificationManager()
    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    /// Schedules a 15-min-before notification for every session of `race`
    /// that isn't already scheduled and hasn't already passed.
    func scheduleNotifications(for race: ChampionshipRace) async {
        for (name, session) in race.allSessions {
            guard let sessionDate = session.dateTime else { continue }

            let identifier = "session-\(race.round)-\(name)"
            let fireDate = sessionDate.addingTimeInterval(-15 * 60)
            let interval = fireDate.timeIntervalSinceNow

            guard interval > 0 else {
//                print("⏭️ Skipping \(identifier) — fire time \(fireDate) already passed")
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = race.raceName
            content.body = "\(name) starts in 15 minutes"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            try? await center.add(request)

            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .medium
            df.timeZone = .current
//            print("✅ Scheduled \(identifier) — session at \(df.string(from: sessionDate)) local, fires at \(df.string(from: fireDate)) local (in \(Int(interval))s)")
        }
    }
}
