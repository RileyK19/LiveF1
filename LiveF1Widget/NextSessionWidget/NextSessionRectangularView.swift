//
//  NextSessionRectangularView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/3/26.
//

import SwiftUI

struct NextSessionRectangularView: View {
    let entry: NextSessionEntry

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        if let race = entry.race {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(race.flagEmoji) \(race.raceName)")
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    ForEach(keySessions(for: race), id: \.name) { s in
                        VStack(spacing: 0) {
                            Text(s.short)
                                .font(.system(size: 9, weight: .bold))
                            Text(s.time)
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                }
            }
        } else {
            Text("No upcoming session")
                .font(.caption2)
        }
    }

    // Pull out just the sessions worth showing in tight lock-screen space —
    // adjust this list if you want different sessions surfaced.
    private func keySessions(for race: ChampionshipRace) -> [(name: String, short: String, time: String)] {
        race.allSessions.compactMap { s in
            let isNext = s.name == entry.sessionName
            let short = shortName(for: s.name)

            let alwaysShow = (s.name.lowercased().contains("qualifying") && !s.name.lowercased().contains("sprint"))
                || s.name.lowercased().contains("sprint")
                || s.name.lowercased().contains("race")

            guard alwaysShow || isNext else { return nil }

            let time = s.session.dateTime.map { timeFormatter.string(from: $0) } ?? "–"
            return (s.name, short, time)
        }
    }

    // Generic short-label mapping that works for any session type, not just a hardcoded few.
    private func shortName(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("sprint") && n.contains("qualifying") { return "Spr Q" }
        if n.contains("sprint") && n.contains("shootout") { return "Spr Q" }
        if n.contains("sprint") { return "Sprint" }
        if n.contains("qualifying") { return "Quali" }
        if n.contains("race") { return "Race" }
        if n.contains("practice") {
            let num = n.last.map(String.init) ?? ""
            return "FP" + num
        }
        return name // fallback: show whatever the raw name is rather than dropping it silently
    }
}
