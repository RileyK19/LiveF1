//
//  F1LiveActivityWidget.swift
//  Redline
//
//  Created by Riley Koo on 9/19/26.
//


import ActivityKit
import WidgetKit
import SwiftUI

struct F1LiveActivityWidget: Widget {
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: F1SessionAttributes.self) { context in
            // Lock screen / banner UI
            LockScreenLiveActivityView(state: context.state, sessionName: context.attributes.sessionName)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    let useGap = context.state.p2Gap != "" && context.state.p3Gap != ""
                    expandedDriver(label: "P1", tla: context.state.leaderTLA, gap: useGap ? "LEADER" : context.state.p1BestLap, highlight: true)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    let useGap = context.state.p2Gap != "" && context.state.p3Gap != ""
                    expandedDriver(label: "P2", tla: context.state.p2TLA, gap: useGap ? context.state.p2Gap : context.state.p2BestLap, highlight: false)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        if !context.state.lapCount.isEmpty {
                            Text("LAP \(context.state.lapCount)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Spacer()

                        if let status = context.state.statusStyle {
                            StatusPill(label: status.label, color: status.color)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Text("P3")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(context.state.p3TLA)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Redline.accent)
                    Text(context.state.leaderTLA)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
            } compactTrailing: {
                let useGap = context.state.p2Gap != "" && context.state.p3Gap != ""
                Text(useGap ? context.state.p2Gap.replacingOccurrences(of: "+", with: "-") : context.state.p1BestLap)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.8))
            } minimal: {
                Text(context.state.leaderTLA)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .keylineTint(Redline.accent)
        }
    }

    @ViewBuilder
    private func expandedDriver(label: String, tla: String, gap: String, highlight: Bool) -> some View {
        Spacer()
            .frame(height: 15)
        VStack(alignment: highlight ? .leading : .trailing, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(highlight ? Redline.accent : .white.opacity(0.5))
            Text(tla)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(gap)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.65))
        }
    }
}

// MARK: - Previews

private extension F1SessionAttributes.ContentState {
    static let green = F1SessionAttributes.ContentState(
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

    static let safetyCar = F1SessionAttributes.ContentState(
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
    
    static let quali = F1SessionAttributes.ContentState(
        leaderTLA: "VER",
        leaderGap: "",
        p2TLA: "NOR",
        p2Gap: "",
        p3TLA: "LEC",
        p3Gap: "",
        trackStatus: "AllClear",
        lapCount: "34",
        p1BestLap: "1:05.334",
        p2BestLap: "1:05.456",
        p3BestLap: "1:06.010"
    )
}

#Preview("Compact", as: .dynamicIsland(.compact), using: F1SessionAttributes(sessionName: "Race")) {
    F1LiveActivityWidget()
} contentStates: {
    F1SessionAttributes.ContentState.green
    F1SessionAttributes.ContentState.safetyCar
    F1SessionAttributes.ContentState.quali
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: F1SessionAttributes(sessionName: "Race")) {
    F1LiveActivityWidget()
} contentStates: {
    F1SessionAttributes.ContentState.green
    F1SessionAttributes.ContentState.safetyCar
    F1SessionAttributes.ContentState.quali
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: F1SessionAttributes(sessionName: "Race")) {
    F1LiveActivityWidget()
} contentStates: {
    F1SessionAttributes.ContentState.green
    F1SessionAttributes.ContentState.quali
}
