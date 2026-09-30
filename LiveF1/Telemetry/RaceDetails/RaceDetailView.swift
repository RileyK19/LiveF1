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
    
//    @EnvironmentObject var currentSessionStore: CurrentSessionStore
//
//    private var viewModel: RaceViewModel? { currentSessionStore.raceViewModel }
    
    @StateObject private var viewModel: RaceViewModel

    init(session: F1PredictorSession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: { RaceViewModel(session: session) }())
    }

    var body: some View {
        Group {
//            if let viewModel {
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
//                        driverPicker(viewModel: viewModel)
                        driverPicker
                        LapTimeChartView(viewModel: viewModel)
                    }
                }
//            } else {
//                ProgressView("Loading race data...")
//            }
        }
        .navigationTitle(session.countryName)
        .navigationBarTitleDisplayMode(.large)
//        .task { currentSessionStore.load(session: session) }
        .task { await viewModel.load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ExportMenu(source: self)
            }
            
//            if let viewModel {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    //                NavigationLink(destination: StrategyAssistantView(viewModel: viewModel)) {
//                    NavigationLink(value: Destination.assistant(viewModel)) {
//                        Image(systemName: "bubble.left.and.text.bubble.right")
//                    }
//                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    //                NavigationLink(destination: StrategyAssistantView(viewModel: viewModel, selectedTab: "Manual")) {
                    NavigationLink(value: Destination.assistant2(viewModel, "Manual")) {
//                        Image(systemName: "slider.horizontal.3")
                        Image(systemName: "wand.and.rays")
                    }
                }
//            }
        }
    }

//    private func driverPicker(viewModel: RaceViewModel) -> some View {
    private var driverPicker: some View {
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


extension RaceDetailView: Exportable {
    var exportContent: some View {
        let usedCompounds = Array(Set(viewModel.annotatedLaps.map { $0.compound }))
            .sorted { $0.rawValue < $1.rawValue }
        
        
        var rawLapTimeRange: ClosedRange<Double> {
            let durations = viewModel.annotatedLaps.map { $0.lapDuration }
            guard !durations.isEmpty else { return 60...120 }
            let sorted = durations.sorted()
            let trimIndex = max(0, Int(Double(sorted.count) * 0.85))
            let trimmed = Array(sorted.prefix(trimIndex + 1))
            let min = (trimmed.min() ?? 60) - 0.5
            let max = (trimmed.max() ?? 120) + 0.5
            return min...max
        }

        var adjustedLapTimeRange: ClosedRange<Double> {
            let deltas = viewModel.adjustedAnnotatedLaps.map { $0.lapDuration }
            guard !deltas.isEmpty else { return -5...5 }
            let sorted = deltas.sorted()
            let trimIndex = max(0, Int(Double(sorted.count) * 0.85))
            let trimmed = Array(sorted.prefix(trimIndex + 1))
            let min = (trimmed.min() ?? -5) - 0.5
            let max = (trimmed.max() ?? 5) + 0.5
            return min...max
        }
        
        return RaceDetailExportLayout(
            annotatedLaps: viewModel.annotatedLaps,
            stintRegressionLines: viewModel.stintRegressionLines,
            rawLapTimeRange: rawLapTimeRange,
            adjustedAnnotatedLaps: viewModel.adjustedAnnotatedLaps,
            adjustedStintRegressionLines: viewModel.adjustedStintRegressionLines,
            adjustedLapTimeRange: adjustedLapTimeRange,
            usedCompounds: usedCompounds,
            stintsForSelectedDriver: viewModel.stintsForSelectedDriver,
            selectedDriver: viewModel.selectedDriverNumber ?? 0,
            sessionName: "\(viewModel.session.circuitShortName) Grand Prix"
        )
    }
    var exportFilename: String { "RaceDetail-\(viewModel.session.circuitShortName)" }
}
