//
//  LockScreenLiveActivityView.swift
//  Redline
//
//  Created by Riley Koo on 9/19/26.
//
import SwiftUI
import WidgetKit

// MARK: - Shared styling

extension F1SessionAttributes.ContentState {
    /// Short label + color for the current track status. Nil when there's nothing to show.
    var statusStyle: (label: String, color: Color)? {
        let s = trackStatus.lowercased()
        guard !s.isEmpty else { return nil }
        if s.contains("red") { return ("RED FLAG", .red) }
        if s.contains("vsc") { return ("VSC", .yellow) }
        if s.contains("safety") || s.contains("sc") && !s.contains("clear") { return ("SAFETY CAR", .orange) }
        if s.contains("yellow") { return ("YELLOW", .yellow) }
        if s.contains("green") || s.contains("clear") { return ("GREEN", .green) }
        return (trackStatus.uppercased(), .gray)
    }
}

enum Redline {
    static let accent = Color(red: 0.90, green: 0.08, blue: 0.14)
    static let background = Color(white: 0.06)
}

struct StatusPill: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.16), in: Capsule())
    }
}

struct DriverRow: View {
    let position: Int
    let tla: String
    let gap: String
    var isLeader: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Text("\(position)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(isLeader ? .white : .white.opacity(0.7))
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isLeader ? Redline.accent : Color.white.opacity(0.12))
                )

            Text(tla)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            Text(gap)
                .font(.system(size: isLeader && gap == "INTERVAL" ? 11 : 15, weight: isLeader && gap == "INTERVAL" ? .bold : .semibold, design: .rounded))
                .tracking(isLeader ? 1 : 0)
                .monospacedDigit()
                .foregroundStyle(isLeader ? Redline.accent : .white.opacity(0.75))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isLeader ? Color.white.opacity(0.08) : Color.clear)
        )
    }
}

// MARK: - Lock screen

struct LockScreenLiveActivityView: View {
    let state: F1SessionAttributes.ContentState
    let sessionName: String

    var body: some View {
        VStack(spacing: 10) {
            header

            VStack(spacing: 2) {
                if state.p2Gap != "", state.p3Gap != "" {
                    DriverRow(position: 1, tla: state.leaderTLA, gap: "INTERVAL", isLeader: true)
                    DriverRow(position: 2, tla: state.p2TLA, gap: state.p2Gap)
                    DriverRow(position: 3, tla: state.p3TLA, gap: state.p3Gap)
                } else {
                    DriverRow(position: 1, tla: state.leaderTLA, gap: state.p1BestLap, isLeader: true)
                    DriverRow(position: 2, tla: state.p2TLA, gap: state.p2BestLap)
                    DriverRow(position: 3, tla: state.p3TLA, gap: state.p3BestLap)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Redline.background)            // solid fill, shows in preview and on device
        .activityBackgroundTint(Redline.background) // keep this so the system tint matches
        .activitySystemActionForegroundColor(.white)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Redline.accent)

            Text(sessionName.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white)

            Spacer()

            if let status = state.statusStyle {
                StatusPill(label: status.label, color: status.color)
            }

            if !state.lapCount.isEmpty {
                Text("LAP \(state.lapCount)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
    }
}

#Preview("Lock Screen", as: .content, using: F1SessionAttributes(sessionName: "Race")) {
    F1LiveActivityWidget()
} contentStates: {
    F1SessionAttributes.ContentState(
        leaderTLA: "VER",
        leaderGap: "",
        p2TLA: "NOR",
        p2Gap: "+2.341",
        p3TLA: "LEC",
        p3Gap: "+5.812",
        trackStatus: "AllClear",
        lapCount: "34",
        p1BestLap: "",
        p2BestLap: "",
        p3BestLap: ""
    )
    F1SessionAttributes.ContentState(
        leaderTLA: "VER",
        leaderGap: "",
        p2TLA: "NOR",
        p2Gap: "+0.812",
        p3TLA: "LEC",
        p3Gap: "+1.204",
        trackStatus: "SafetyCar",
        lapCount: "41",
        p1BestLap: "",
        p2BestLap: "",
        p3BestLap: ""
    )
    F1SessionAttributes.ContentState(
        leaderTLA: "VER",
        leaderGap: "",
        p2TLA: "NOR",
        p2Gap: "",
        p3TLA: "LEC",
        p3Gap: "",
        trackStatus: "AllClear",
        lapCount: "34",
        p1BestLap: "1:29.759",
        p2BestLap: "1:29.952",
        p3BestLap: "1:30.001"
    )

}
