//
//  SessionBanner.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI

struct SessionBanner: View {
    @AppStorage("isDark") private var isDark = false
    let store: F1SessionStore

    private var flagColour: Color {
        switch store.header.flagStatus {
        case "1": return .green
        case "2", "4", "6", "7": return .yellow
        case "5": return .red
        default: return .clear
        }
    }

    var body: some View {
        let header = store.header
        let flag = flagColour

        HStack(spacing: 12) {
            if flag != .clear {
                Rectangle()
                    .fill(flag)
                    .frame(width: 4, height: 24)
                    .cornerRadius(2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(header.sessionName)
                    .font(.caption.bold())
                    .foregroundStyle(isDark ? .white : .black)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if !header.lapText.isEmpty {
                        Text(header.lapText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let r = remaining(at: ctx.date, header: header)
                        if !r.isEmpty {
                            Text(r)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
            PulseDot(store: store)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
    }

    private func remaining(at now: Date, header: SessionHeader) -> String {
        guard let base = header.remainingBase else { return "" }
        guard header.extrapolating, let utc = header.clockUtc else {
            return header.remainingText ?? ""
        }
        let elapsed = now.timeIntervalSince(utc) - store.delaySeconds
        return formatDuration(max(0, base - elapsed))
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}

private struct PulseDot: View {
    let store: F1SessionStore
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(pulse ? Color.green : Color.green.opacity(0.2))
            .frame(width: 6, height: 6)
            .animation(.easeOut(duration: 0.3), value: pulse)
            .onChange(of: store.tick) { _, _ in
                pulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { pulse = false }
            }
    }
}
