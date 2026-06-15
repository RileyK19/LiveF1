//
//  SessionBanner.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI

struct SessionBanner: View {
    @AppStorage("isDark") private var isDark = false

    @ObservedObject var store: F1SessionStore
    
    @State private var dotPulse = false

    var sessionInfo: [String: Any] {
        store.rawTopics["SessionInfo"] as? [String: Any] ?? [:]
    }
    var lapCount: [String: Any] {
        store.rawTopics["LapCount"] as? [String: Any] ?? [:]
    }
    var clock: [String: Any] {
        store.rawTopics["ExtrapolatedClock"] as? [String: Any] ?? [:]
    }
    var trackStatus: [String: Any] {
        store.rawTopics["TrackStatus"] as? [String: Any] ?? [:]
    }

    var flagColour: Color {
        switch trackStatus["Status"] as? String {
        case "1": return .green
        case "2": return .yellow
        case "4", "6", "7": return .yellow
        case "5": return .red
        default: return .clear
        }
    }

    var sessionName: String {
        let meeting = (sessionInfo["Meeting"] as? [String: Any])?["Name"] as? String ?? ""
        let session = sessionInfo["Name"] as? String ?? ""
        return "\(meeting) — \(session)"
    }

    var lapText: String {
        guard let current = lapCount["CurrentLap"] as? Int,
              let total = lapCount["TotalLaps"] as? Int
        else { return "" }
        return "Lap \(current)/\(total)"
    }

    var remainingTime: String {
        clock["Remaining"] as? String ?? ""
    }

    var body: some View {
        HStack(spacing: 12) {
            if flagColour != .clear {
                Rectangle()
                    .fill(flagColour)
                    .frame(width: 4, height: 24)
                    .cornerRadius(2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(sessionName)
                    .font(.caption.bold())
                    .foregroundStyle(isDark ? .white : .black)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if !lapText.isEmpty {
                        Text(lapText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !remainingTime.isEmpty {
                        Text(remainingTime)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Text("\(store.updateCount)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            Circle()
                .fill(dotPulse ? Color.green : Color.green.opacity(0.2))
                .frame(width: 6, height: 6)
                .animation(.easeOut(duration: 0.3), value: dotPulse)
                .onChange(of: store.updateCount) { old, new in
                    dotPulse = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dotPulse = false
                    }
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
    }
}
