//
//  LockScreenLiveActivityView.swift
//  Redline
//
//  Created by Riley Koo on 9/19/26.
//

import SwiftUI
import WidgetKit

struct LockScreenLiveActivityView: View {
    let state: F1SessionAttributes.ContentState
    let sessionName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(sessionName, systemImage: "flag.checkered")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
                if !state.trackStatus.isEmpty {
                    Text(state.trackStatus)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(trackStatusColor.opacity(0.2))
                        .foregroundColor(trackStatusColor)
                        .clipShape(Capsule())
                }
                if !state.lapCount.isEmpty {
                    Text("Lap \(state.lapCount)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Divider().opacity(0.3)

            VStack(spacing: 6) {
                driverRow(pos: 1, tla: state.leaderTLA, gap: "LEADER")
                driverRow(pos: 2, tla: state.p2TLA, gap: state.p2Gap)
                driverRow(pos: 3, tla: state.p3TLA, gap: state.p3Gap)
            }
        }
        .padding(16)
        .activityBackgroundTint(Color.black)
        .activitySystemActionForegroundColor(Color.white)
    }

    @ViewBuilder
    private func driverRow(pos: Int, tla: String, gap: String) -> some View {
        HStack {
            Text("\(pos)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .frame(width: 18, alignment: .leading)
                .foregroundStyle(.secondary)

            Text(tla)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(width: 50, alignment: .leading)

            Spacer()

            Text(gap)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(pos == 1 ? .purple : .secondary)
        }
    }

    private var trackStatusColor: Color {
        switch state.trackStatus.lowercased() {
        case let s where s.contains("green"): return .green
        case let s where s.contains("yellow"): return .yellow
        case let s where s.contains("red"): return .red
        case let s where s.contains("safety"): return .orange
        default: return .gray
        }
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
        lapCount: "34"
    )
}
