//
//  SpoilerWarningView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/24/26.
//

import SwiftUI

struct SpoilerWarningView: View {
    let title: String
    var message: String = "This may contain spoilers. Are you sure you want to continue?"
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.yellow)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button(role: .cancel) {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(24)
    }
}

extension View {
    func spoilerWarning(
        isPresented: Binding<Bool>,
        title: String = "Spoiler Warning",
        message: String = "This may contain spoilers. Are you sure you want to continue?",
        onContinue: @escaping () -> Void
    ) -> some View {
        self.overlay {
            if isPresented.wrappedValue {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)

                SpoilerWarningView(
                    title: title,
                    message: message,
                    onContinue: {
                        isPresented.wrappedValue = false
                        onContinue()
                    },
                    onCancel: {
                        isPresented.wrappedValue = false
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: isPresented.wrappedValue)
    }
}
