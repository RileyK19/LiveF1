//
//  ConstructorStandingsCardView.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//

import SwiftUI

struct ConstructorStandingsCardView: View {
    let result: GetConstructorStandingsResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Constructor Standings")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(Array(result.standings.prefix(10)), id: \.constructorName) { entry in
                HStack {
                    Text("\(entry.position)")
                        .font(.caption.monospacedDigit())
                        .frame(width: 20, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    Text(entry.constructorName)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(entry.points)) pts")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
