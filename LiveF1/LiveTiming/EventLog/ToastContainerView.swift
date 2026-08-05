//
//  ToastContainerView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/29/26.
//

import SwiftUI

struct ToastContainerView: View {
    @ObservedObject var store: F1SessionStore

    var body: some View {
        VStack {
            if let toast = store.currentToast {
                Group {
                    switch toast {
                    case .radio(let id):
                        RadioToast(store: store, msgId: id)
                    case .raceControl(let id):
                        RaceControlToast(store: store, msgId: id)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture {
                    withAnimation { store.currentToast = nil }
                    store.advanceToastIfNeeded() // note: needs to be non-private if called from here
                }
            }
            Spacer()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.currentToast?.id)
        .padding(.bottom, 24)
    }
}
