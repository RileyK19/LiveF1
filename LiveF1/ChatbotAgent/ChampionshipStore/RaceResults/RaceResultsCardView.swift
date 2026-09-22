//
//  RaceResultsCardView.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//

import SwiftUI

struct RaceResultsCardView: View {
    let result: GetRaceResultsResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Race Results")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(Array(result.results.prefix(10)), id: \.driverName) { entry in
                HStack {
                    Text("\(entry.position)")
                        .font(.caption.monospacedDigit())
                        .frame(width: 20, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.driverName)
                            .font(.subheadline)
                        Text(entry.constructorName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if entry.status != "Finished" {
                        Text(entry.status)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    } else {
                        Text("\(Int(entry.points)) pts")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
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
