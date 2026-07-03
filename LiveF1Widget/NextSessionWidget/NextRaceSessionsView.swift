//
//  NextRaceSessionsView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/3/26.
//

import SwiftUI

struct NextRaceSessionsView: View {
    let entry: NextSessionEntry

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        if let race = entry.race {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(race.flagEmoji) \(race.raceName)")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Spacer()
                    if let dt = entry.session?.dateTime {
                        Text(dt, style: .relative)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }

                HStack(spacing: 0) {
                    ForEach(race.allSessions, id: \.name) { s in
                        SessionColumn(
                            name: s.name,
                            isNext: s.name == entry.sessionName,
                            day: s.session.dateTime.map { dayFormatter.string(from: $0) },
                            time: s.session.dateTime.map { timeFormatter.string(from: $0) }
                        )
                        if s.name != race.allSessions.last?.name {
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding()
        } else {
            Text("No race data cached")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
        }
    }
}

private struct SessionColumn: View {
    let name: String
    let isNext: Bool
    let day: String?
    let time: String?

    var body: some View {
        VStack(spacing: 3) {
            Text(shortName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isNext ? .white : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isNext ? Color.red : Color.secondary.opacity(0.15), in: Capsule())

            Text(day ?? "–")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Text(time ?? "TBD")
                .font(.system(size: 11, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
    }

    // Shortens "Practice 1" -> "FP1", "Qualifying" -> "Quali", "Race" stays "Race", etc.
    private var shortName: String {
        switch name.lowercased() {
        case let n where n.contains("practice 1"): return "FP1"
        case let n where n.contains("practice 2"): return "FP2"
        case let n where n.contains("practice 3"): return "FP3"
        case let n where n.contains("sprint qualifying"), let n where n.contains("sprint shootout"): return "Spr Q"
        case let n where n.contains("sprint"): return "Sprint"
        case let n where n.contains("qualifying"): return "Quali"
        case let n where n.contains("race"): return "Race"
        default: return name
        }
    }
}
