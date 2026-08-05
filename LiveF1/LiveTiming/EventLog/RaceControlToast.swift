//
//  RaceControlToast.swift
//  LiveF1
//
//  Created by Riley Koo on 7/29/26.
//

import SwiftUI

struct RaceControlToast: View {
    @ObservedObject var store: F1SessionStore
    let msgId: String

    var msg: RaceControlMessage? {
        store.raceControlMessages.first(where: { $0.id == msgId })
    }
    @AppStorage("isDark") private var isDark = false

    var flagColor: Color {
        switch msg?.flag {
        case "YELLOW", "DOUBLE YELLOW": return .yellow
        case "RED": return .red
        case "GREEN", "CLEAR": return .green
        case "BLUE": return .blue
        default: return .secondary
        }
    }

    var body: some View {
        guard let msg else { return AnyView(EmptyView()) }
        return AnyView(
            HStack(spacing: 10) {
                Rectangle()
                    .fill(flagColor)
                    .frame(width: 3, height: 32)
                    .cornerRadius(1.5)

                VStack(alignment: .leading, spacing: 2) {
                    Text("🏁 Race Control")
                        .font(.caption.bold())
                        .foregroundStyle(isDark ? .white : .black)
                    Text(msg.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .shadow(radius: 4)
            .padding(.horizontal, 12)
        )
    }
}
