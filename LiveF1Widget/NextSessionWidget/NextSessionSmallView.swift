//
//  NextSessionSmallView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/3/26.
//

import SwiftUI

struct NextSessionSmallView: View {
    let entry: NextSessionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let race = entry.race, let session = entry.session {
                Text("\(race.flagEmoji) \(race.raceName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(entry.sessionName ?? "Error loading")
                    .font(.headline)

                Spacer()

                if let dt = session.dateTime {
                    Text(dt, style: .relative)
                        .font(.body.weight(.bold))
                        .foregroundStyle(.red)
                        .contentTransition(.numericText())
                    Text(dt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No upcoming session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
