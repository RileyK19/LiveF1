//
//  NextSessionSmallView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/3/26.
//

import SwiftUI
import WidgetKit

struct NextSessionSmallView: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: NextSessionEntry
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
//        VStack(alignment: .leading, spacing: 6) {
            if let race = entry.race {
                HStack {
                    VStack(alignment: .center, spacing: 6) {
                        ChampionshipTrackView(trackName: race.circuit.location.locality, width: 70, height: 70, primary: Color.white, secondary: Color.red)
                        
                        Text("\(race.raceName.replacingOccurrences(of: "Grand Prix", with: "GP"))")
                            .font(.system(size: 11, weight: .bold))
                        
                        if let dt = entry.session?.dateTime {
                            Text(dt, style: .relative)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.red)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 6) {
                        ForEach(keySessions(for: race), id: \.name) { s in
                            let isNext = s.name == entry.sessionName
                            
                            VStack(spacing: 0) {
                                Text(s.short)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(isNext ? .white : .secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isNext ? Color.red : Color.secondary.opacity(0.15), in: Capsule())
                                Text(s.time)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .containerBackground(for: .widget) {
                    if let race = entry.race {
                        ZStack {
                            colorScheme == .dark ? Color.black : Color.white
                            TrackColors.softGradient(for: race.circuit.location.locality, opacity: 0.5)
                        }
                    }
                }

//                Text("\(race.flagEmoji) \(race.raceName)")
//                    .font(.caption.weight(.semibold))
//                    .foregroundStyle(.secondary)
//                    .lineLimit(1)
//
//                Text(entry.sessionName ?? "Error loading")
//                    .font(.headline)
//
//                Spacer()
//
//                if let dt = session.dateTime {
//                    Text(dt, style: .relative)
//                        .font(.body.weight(.bold))
//                        .foregroundStyle(.red)
//                        .contentTransition(.numericText())
//                    Text(dt, style: .time)
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                }
            } else {
                Text("No upcoming session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
//        }
//        .padding()
    }
    
    // Pull out just the sessions worth showing in tight lock-screen space —
    // adjust this list if you want different sessions surfaced.
    private func keySessions(for race: ChampionshipRace) -> [(name: String, short: String, time: String)] {
        race.allSessions.compactMap { s in
            let isNext = s.name == entry.sessionName
            let short = shortName(for: s.name)

            let alwaysShow = (s.name.lowercased().contains("quali") && (race.sprint == nil || ((entry.sessionName?.lowercased().contains("sprint")) != nil)))
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
