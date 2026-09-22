//
//  RaceDetailView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//

import SwiftUI
import Combine

struct RaceDetailView: View {
    let session: F1PredictorSession
    
    @EnvironmentObject var currentSessionStore: CurrentSessionStore

    private var viewModel: RaceViewModel? { currentSessionStore.raceViewModel }
    
//    @StateObject private var viewModel: RaceViewModel
//
//    init(session: F1PredictorSession) {
//        self.session = session
//        _viewModel = StateObject(wrappedValue: { RaceViewModel(session: session) }())
//    }

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading {
                    ProgressView("Loading race data...")
                } else if let error = viewModel.error {
                    VStack(spacing: 12) {
                        Text("Failed to load race data").font(.headline)
                        Text(error).font(.caption).foregroundStyle(.secondary)
                        Button("Retry") { Task { await viewModel.load() } }
                    }
                } else {
                    VStack(spacing: 0) {
                        driverPicker(viewModel: viewModel)
                        LapTimeChartView(viewModel: viewModel)
                    }
                }
            } else {
                ProgressView("Loading race data...")
            }
        }
        .navigationTitle(session.countryName)
        .navigationBarTitleDisplayMode(.large)
        .task { currentSessionStore.load(session: session) }
        .toolbar {
            if let viewModel {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    //                NavigationLink(destination: StrategyAssistantView(viewModel: viewModel)) {
//                    NavigationLink(value: Destination.assistant(viewModel)) {
//                        Image(systemName: "bubble.left.and.text.bubble.right")
//                    }
//                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    //                NavigationLink(destination: StrategyAssistantView(viewModel: viewModel, selectedTab: "Manual")) {
                    NavigationLink(value: Destination.assistant2(viewModel, "Manual")) {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
        }
    }

    private func driverPicker(viewModel: RaceViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.drivers, id: \.self) { driver in
                    Button("#\(driver)") {
                        viewModel.selectedDriverNumber = driver
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.selectedDriverNumber == driver ? .red : .secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}
