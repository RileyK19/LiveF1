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
    
//    @State private var radioToast: RadioMessage?
    @State private var toastTimer: Timer?
    
    private var showPitPredictions: Bool {
        !store.pitPredictions.isEmpty
    }

    var body: some View {
        let drivers = store.drivers
        // let _ = print("🎨 rendering: \(drivers.count) drivers, updateCount: \(store.updateCount)")
        return VStack(spacing: 0) {
            SessionBanner(store: store)
            Divider().opacity(0.2)
            if store.isDelayRampingUp {
                DelayProgressView(store: store)
            }
            Spacer()
            Divider().opacity(0.2)
            ScrollView {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        HeaderRow(showPitPredictions: showPitPredictions)
                        ForEach(drivers) { driver in
                            Button {
                                selectedDriver = driver
                            } label: {
                                DriverRow(driver: driver,
                                          isLeader: driver.position == 1,
                                          pit: store.pitPredictions[driver.id],
                                          showPitPredictions: showPitPredictions
                                )
                            }
                            .buttonStyle(.plain)
                            Divider().opacity(0.2)
                        }
                    }
                    .frame(minWidth: UIScreen.main.bounds.width)
                }
            }
            .navigationDestination(item: $selectedDriver) { driver in
                //                DriverDetailView(driver: driver, store: store)
                DriverDetailView(driverID: driver.id, store: store)
            }
            .blur(radius: store.isDelayRampingUp ? 20 : 0)
            .allowsHitTesting(!store.isDelayRampingUp)
            .animation(.easeInOut(duration: 0.3), value: store.isDelayRampingUp)
//            .overlay(alignment: .top) {
//                if let msg = radioToast {
//                    RadioToast(store: store, msgId: msg.id)
//                        .transition(.move(edge: .top).combined(with: .opacity))
//                        .padding(.top, 8)
//                }
//            }
//            .animation(.spring(), value: radioToast?.id)
//            .onChange(of: store.radioMessages.count) { old, new in
//                print("📻 onChange: \(old) → \(new)")
//                guard new > old, let msg = store.radioMessages.first else { return }
//                toastTimer?.invalidate()
//                radioToast = msg
//                toastTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
//                    DispatchQueue.main.async { radioToast = nil }
//                }
//            }
//            .onAppear {
//                if let msg = store.radioMessages.first {
//                    radioToast = msg
//                    toastTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
//                        DispatchQueue.main.async { radioToast = nil }
//                    }
//                }
//            }
        }
        .background(isDark ? Color.black : Color.white)
        .navigationTitle("Timing")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: store.isDelayRampingUp)
    }
}

struct DelayProgressView: View {
    @State private var rampBaseline: TimeInterval = 0
    @ObservedObject var store: F1SessionStore
    
    private var rampProgress: Double {
        guard rampBaseline > 0 else { return 1 }
        return min(1, max(0, 1 - (store.delayRampRemaining / rampBaseline)))
    }
    
    var body: some View {
        VStack (spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Catching up to \(Int(store.delaySeconds))s delay — \(Int(store.delayRampRemaining))s left")
                        .font(.caption)
                }
                ProgressView(value: rampProgress)
                    .tint(.yellow)
                    .padding(.horizontal, 12)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.yellow)
                    .opacity(0.75)
            )
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            
            Divider().opacity(0.2)
        }
        .onChange(of: store.isDelayRampingUp) { was, isNow in
            if isNow && !was {
                rampBaseline = store.delayRampRemaining
            }
        }
        .onAppear {
            if store.isDelayRampingUp {
                rampBaseline = store.delayRampRemaining
            }
        }
    }
}
