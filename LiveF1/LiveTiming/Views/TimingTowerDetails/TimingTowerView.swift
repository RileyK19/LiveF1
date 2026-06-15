//
//  TimingTowerView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/5/26.
//


import SwiftUI

struct TimingTowerView: View {
    @ObservedObject var store: F1SessionStore
    @State private var selectedDriver: Driver?
    @AppStorage("isDark") private var isDark = false
    
    @State private var radioToast: RadioMessage?
    @State private var toastTimer: Timer?

    var body: some View {
        let drivers = store.drivers
        let _ = print("🎨 rendering: \(drivers.count) drivers, updateCount: \(store.updateCount)")
        return VStack(spacing: 0) {
            SessionBanner(store: store)
            Divider().opacity(0.2)
            ScrollView {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        HeaderRow()
                        ForEach(drivers) { driver in
                            Button {
                                selectedDriver = driver
                            } label: {
                                DriverRow(driver: driver, isLeader: driver.position == 1)
                            }
                            .buttonStyle(.plain)
                            Divider().opacity(0.2)
                        }
                    }
                    .frame(minWidth: UIScreen.main.bounds.width)
                }
            }
            .navigationDestination(item: $selectedDriver) { driver in
                DriverDetailView(driver: driver, store: store)
            }
            .overlay(alignment: .top) {
                if let msg = radioToast {
                    RadioToast(store: store, msgId: msg.id)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
            .animation(.spring(), value: radioToast?.id)
            .onChange(of: store.radioMessages.count) { old, new in
                print("📻 onChange: \(old) → \(new)")
                guard new > old, let msg = store.radioMessages.first else { return }
                toastTimer?.invalidate()
                radioToast = msg
                toastTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
                    DispatchQueue.main.async { radioToast = nil }
                }
            }
            .onAppear {
                if let msg = store.radioMessages.first {
                    radioToast = msg
                    toastTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
                        DispatchQueue.main.async { radioToast = nil }
                    }
                }
            }
        }
        .background(isDark ? Color.black : Color.white)
        .navigationTitle("Timing")
        .navigationBarTitleDisplayMode(.inline)
    }
}
