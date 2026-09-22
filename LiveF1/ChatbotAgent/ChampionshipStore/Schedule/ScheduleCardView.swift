//
//  ScheduleCardView.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//

import SwiftUI

struct ScheduleCardView: View {
    let result: GetScheduleResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Round \(result.round)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(result.raceName)
                    .font(.subheadline.bold())
                Text("\(result.circuitName) · \(result.locality), \(result.country)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(result.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let countdown = result.countdown {
                        Text("· \(countdown)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.red)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(result.sessions, id: \.name) { session in
                    HStack {
                        Text(session.name)
                            .font(.caption.bold())
                            .foregroundStyle(session.isPast ? .secondary : .primary)
                            .frame(width: 50, alignment: .leading)
                        Text(session.formattedDateTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if session.isPast {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
