//
//  SessionPickerCardView.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//


import SwiftUI

struct SessionPickerCardView: View {
    let options: [SessionOption]
    @ObservedObject var coordinator: SessionSelectionCoordinator

    private var isResolved: Bool { coordinator.currentOptions == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isResolved ? "Session selected" : "Which session did you mean?")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(options, id: \.self) { option in
                Button {
                    coordinator.resolve(with: option)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(option.raceName) — \(option.sessionName)")
                                .font(.subheadline)
                            Text(option.formattedDateTime)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isResolved)
                .foregroundStyle(.primary)
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
