//
//  StrategyAssistantView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/15/26.
//


//  StrategyAssistantView.swift

import SwiftUI
import Charts

struct StrategyAssistantView: View {
    @ObservedObject var viewModel: RaceViewModel
    @StateObject private var translator = StrategyTranslator()
    @State private var prompt: String = ""
    @State private var messages: [ChatMessage] = []
    @FocusState private var inputFocused: Bool

    var body: some View {
        TabView {
            // AI tab
            aiChatView
                .tabItem {
                    Label("AI Assistant", systemImage: "bubble.left.and.text.bubble.right")
                }

            // Manual tab
            ManualStrategyView(viewModel: viewModel)
                .tabItem {
                    Label("Manual", systemImage: "slider.horizontal.3")
                }
        }
        .navigationTitle("Strategy")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { translator.error != nil },
            set: { if !$0 { translator.error = nil } }
        )) {
            Button("OK") { translator.error = nil }
        } message: {
            Text(translator.error ?? "")
        }
    }

    private var aiChatView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty { suggestionsView }
                        ForEach(messages) { message in
                            ChatBubbleView(message: message, viewModel: viewModel)
                                .id(message.id)
                        }
                        if translator.isThinking {
                            thinkingIndicator.id("thinking")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                }
            }

            Divider()

            HStack(spacing: 12) {
                TextField("Ask about strategy...", text: $prompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($inputFocused)

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(prompt.isEmpty ? .secondary : .red)
                }
                .disabled(prompt.isEmpty || translator.isThinking)
            }
            .padding(12)
            .background(.bar)
        }
    }

    // MARK: - Suggestions

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try asking...")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    prompt = suggestion
                    send()
                } label: {
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var suggestions: [String] {
        guard let driver = viewModel.selectedDriverNumber else { return [] }
        let stints = viewModel.stintsForSelectedDriver
        let stopCount = max(0, stints.count - 1)
        return [
            "Would a \(stopCount + 1) stop have been faster for #\(driver)?",
            "What if #\(driver) pitted 5 laps earlier?",
            "What if #\(driver) used softs at the end?",
            "Show me an aggressive undercut strategy for #\(driver)"
        ]
    }

    // MARK: - Thinking indicator

    private var thinkingIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(0.4)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(i) * 0.2),
                        value: translator.isThinking
                    )
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Send

    private func send() {
        guard !prompt.isEmpty,
              let driver = viewModel.selectedDriverNumber
        else { return }

        let userMessage = ChatMessage(role: .user, text: prompt)
        messages.append(userMessage)
        let currentPrompt = prompt
        prompt = ""
        inputFocused = false

        let context = StrategyContextBuilder.build(
            session: viewModel.session,
            laps: viewModel.laps,
            stints: viewModel.stints,
            selectedDriver: driver
        )

        Task { @MainActor in
            if let generatedStints = await translator.translate(
                prompt: currentPrompt,
                context: context
            ) {
                viewModel.hypotheticalStints = generatedStints
                // text confirmation first
                messages.append(ChatMessage(role: .assistant, text: formatResponse(generatedStints)))
                // then result card
                let delta = viewModel.calculateTimeDeltaVsDriver(hypothetical: generatedStints)
                messages.append(ChatMessage(
                    role: .assistant,
                    actual: viewModel.stintsForSelectedDriver,
                    hypothetical: generatedStints,
                    timeDelta: delta
                ))
            } else if let error = translator.error {
                messages.append(ChatMessage(role: .assistant, text: "Sorry, I couldn't process that: \(error)"))
            }
        }
    }

    private func formatResponse(_ stints: [F1PredictorStint]) -> String {
        let lines = stints.map { "Stint \($0.stintNumber): \($0.compound) laps \($0.lapStart)–\($0.lapEnd ?? 0)" }
        return "Here's the strategy:\n" + lines.joined(separator: "\n") + "\n\nSwipe to the chart to see how it compares."
    }
}

// MARK: - Chat models

struct ChatMessage: Identifiable {
    let id = UUID().uuidString
    let role: Role
    let content: Content

    enum Role {
        case user
        case assistant
    }

    enum Content {
        case text(String)
        case strategyResult(actual: [F1PredictorStint], hypothetical: [F1PredictorStint], timeDelta: Double?)
    }

    // convenience inits
    init(role: Role, text: String) {
        self.role = role
        self.content = .text(text)
    }

    init(role: Role, actual: [F1PredictorStint], hypothetical: [F1PredictorStint], timeDelta: Double?) {
        self.role = role
        self.content = .strategyResult(actual: actual, hypothetical: hypothetical, timeDelta: timeDelta)
    }
}

struct ChatBubbleView: View {
    let message: ChatMessage
    @ObservedObject var viewModel: RaceViewModel

    var body: some View {
        switch message.content {
        case .text(let text):
            HStack {
                if message.role == .user { Spacer() }
                Text(text)
                    .font(.subheadline)
                    .padding(12)
                    .background(message.role == .user ? Color.red.opacity(0.8) : Color.secondary.opacity(0.1))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
                if message.role == .assistant { Spacer() }
            }
        case .strategyResult(let actual, let hypothetical, let timeDelta):
            StrategyResultCard(actual: actual, hypothetical: hypothetical, timeDelta: timeDelta, viewModel: viewModel)
        }
    }
}

struct StrategyResultCard: View {
    let actual: [F1PredictorStint]
    let hypothetical: [F1PredictorStint]
    let timeDelta: Double?
    @ObservedObject var viewModel: RaceViewModel
    @State private var page = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Time delta header
            if let delta = timeDelta {
                HStack {
                    Image(systemName: delta < 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(delta < 0 ? .green : .red)
                    Text(delta < 0
                         ? "Hypothetical is \(formatDelta(abs(delta))) faster"
                         : "Hypothetical is \(formatDelta(abs(delta))) slower")
                        .font(.subheadline.bold())
                }
            }

            Divider()

            TabView(selection: $page) {
                stintComparisonPage
                    .tag(0)
                deltaChartPage
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 200)
        }
        .padding(12)
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Page 1: Stint comparison

    private var stintComparisonPage: some View {
        HStack(alignment: .top, spacing: 16) {
            stintColumn(title: "Actual", stints: actual)
            Divider()
            stintColumn(title: "Hypothetical", stints: hypothetical)
        }
        .padding(.bottom, 24) // room for page dots
    }

    private func stintColumn(title: String, stints: [F1PredictorStint]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(stints) { stint in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: TyreCompound(rawValue: stint.compound)?.color ?? "#888888"))
                        .frame(width: 8, height: 8)
                    Text("\(stint.compound.prefix(3)) \(stint.lapStart)–\(stint.lapEnd ?? 0)")
                        .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Page 2: Cumulative delta chart

    private var deltaChartPage: some View {
        Chart {
            // Zero reference
            RuleMark(y: .value("Even", 0))
                .foregroundStyle(.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            ForEach(cumulativeDeltaPoints, id: \.lap) { point in
                LineMark(
                    x: .value("Lap", point.lap),
                    y: .value("Delta", point.delta)
                )
                .foregroundStyle(point.delta < 0 ? Color.green : Color.red)

                AreaMark(
                    x: .value("Lap", point.lap),
                    y: .value("Delta", point.delta)
                )
                .foregroundStyle(
                    (point.delta < 0 ? Color.green : Color.red).opacity(0.1)
                )
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let s = value.as(Double.self) {
                        Text(formatDelta(s))
                            .font(.caption2)
                    }
                }
                AxisGridLine()
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) {
                AxisValueLabel()
                    .font(.caption2)
                AxisGridLine()
            }
        }
        .padding(.bottom, 24)
        .padding(.horizontal, 4)
    }

    // MARK: - Cumulative delta calculation

    // In your View / ChartView

    private var cumulativeDeltaPoints: [DeltaPoint] {
        guard let median = viewModel.driverMedianLapTime,
              let trackModel = viewModel.trackEvolutionModel
        else { return [] }

        return StrategyCalculator.shared.cumulativeDeltaPoints(
            actual: actual,
            hypothetical: hypothetical,
            median: median,
            trackModel: trackModel,
            annotatedLaps: viewModel.annotatedLaps
        )
    }

    // MARK: - Helpers

    private func formatDelta(_ seconds: Double) -> String {
        let sign = seconds >= 0 ? "+" : ""
        return String(format: "\(sign)%.1fs", seconds)
    }
}

// MARK: Preview

private struct StrategyAssistantPreviewWrapper: View {
    @StateObject private var viewModel: RaceViewModel

    init() {
        let session = F1PredictorSession(
            sessionKey: 11299,
            sessionType: "Race",
            sessionName: "Race",
            dateStart: nil,
            dateEnd: nil,
            meetingKey: 1286,
            circuitKey: 22,
            circuitShortName: "Monte Carlo",
            countryKey: 114,
            countryCode: "MON",
            countryName: "Monaco",
            location: "Monte Carlo",
            gmtOffset: "02:00:00",
            year: 2026,
            isCancelled: false
        )
        let vm = RaceViewModel(session: session)
        vm.selectedDriverNumber = 1

        let mockActualStints: [F1PredictorStint] = [
            F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 1, driverNumber: 1, lapStart: 1, lapEnd: 28, compound: "MEDIUM", tyreAgeAtStart: 0),
            F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 2, driverNumber: 1, lapStart: 29, lapEnd: 52, compound: "HARD", tyreAgeAtStart: 0),
            F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 3, driverNumber: 1, lapStart: 53, lapEnd: 78, compound: "SOFT", tyreAgeAtStart: 0)
        ]

        vm.laps = (1...78).map { lapNumber in
            let tyreAge: Int
            let base: Double
            if lapNumber <= 28 {
                tyreAge = lapNumber - 1
                base = 75.0 + Double(tyreAge) * 0.05
            } else if lapNumber <= 52 {
                tyreAge = lapNumber - 29
                base = 75.8 + Double(tyreAge) * 0.03
            } else {
                tyreAge = lapNumber - 53
                base = 74.5 + Double(tyreAge) * 0.08
            }
            return F1Lap(
                meetingKey: 1286, sessionKey: 11299, driverNumber: 1,
                lapNumber: lapNumber, dateStart: nil,
                durationSector1: base * 0.3, durationSector2: base * 0.4, durationSector3: base * 0.3,
                i1Speed: 240, i2Speed: 280,
                isPitOutLap: lapNumber == 29 || lapNumber == 53,
                lapDuration: base + Double.random(in: -0.2...0.2),
                segmentsSector1: nil, segmentsSector2: nil, segmentsSector3: nil,
                stSpeed: 310
            )
        }

        vm.stints = mockActualStints

        for driver in [3, 11, 44, 16, 55] {
            vm.laps += (1...78).map { lap in
                F1Lap(
                    meetingKey: 1286, sessionKey: 11299, driverNumber: driver,
                    lapNumber: lap, dateStart: nil,
                    durationSector1: nil, durationSector2: nil, durationSector3: nil,
                    i1Speed: nil, i2Speed: nil, isPitOutLap: false,
                    lapDuration: 75.5 + Double(lap) * -0.02 + Double.random(in: -0.3...0.3),
                    segmentsSector1: nil, segmentsSector2: nil, segmentsSector3: nil,
                    stSpeed: nil
                )
            }
            vm.stints += [
                F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 1, driverNumber: driver, lapStart: 1, lapEnd: 30, compound: "MEDIUM", tyreAgeAtStart: 0),
                F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 2, driverNumber: driver, lapStart: 31, lapEnd: 78, compound: "HARD", tyreAgeAtStart: 0)
            ]
        }

        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        let mockActualStints: [F1PredictorStint] = [
            F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 1, driverNumber: 1, lapStart: 1, lapEnd: 28, compound: "MEDIUM", tyreAgeAtStart: 0),
            F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 2, driverNumber: 1, lapStart: 29, lapEnd: 52, compound: "HARD", tyreAgeAtStart: 0),
            F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 3, driverNumber: 1, lapStart: 53, lapEnd: 78, compound: "SOFT", tyreAgeAtStart: 0)
        ]

        let mockHypotheticalStints: [F1PredictorStint] = [
            F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 1, driverNumber: 1, lapStart: 1, lapEnd: 20, compound: "SOFT", tyreAgeAtStart: 0),
            F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 2, driverNumber: 1, lapStart: 21, lapEnd: 45, compound: "MEDIUM", tyreAgeAtStart: 0),
            F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 3, driverNumber: 1, lapStart: 46, lapEnd: 62, compound: "HARD", tyreAgeAtStart: 0),
            F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 4, driverNumber: 1, lapStart: 63, lapEnd: 78, compound: "SOFT", tyreAgeAtStart: 0)
        ]

        let messages: [ChatMessage] = [
            ChatMessage(role: .user, text: "Would a 3 stop have been faster for #1?"),
            ChatMessage(role: .assistant, text: "Here's the strategy:\nStint 1: MEDIUM laps 1–28\nStint 2: HARD laps 29–52\nStint 3: SOFT laps 53–78"),
            ChatMessage(role: .assistant, actual: mockActualStints, hypothetical: mockHypotheticalStints, timeDelta: -4.7),
            ChatMessage(role: .user, text: "What if he pitted 5 laps earlier?"),
            ChatMessage(role: .assistant, text: "Here's the strategy:\nStint 1: MEDIUM laps 1–23\nStint 2: HARD laps 24–52\nStint 3: SOFT laps 53–78"),
            ChatMessage(role: .assistant, actual: mockActualStints, hypothetical: [
                F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 1, driverNumber: 1, lapStart: 1, lapEnd: 23, compound: "MEDIUM", tyreAgeAtStart: 0),
                F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 2, driverNumber: 1, lapStart: 24, lapEnd: 52, compound: "HARD", tyreAgeAtStart: 0),
                F1PredictorStint(meetingKey: 1286, sessionKey: 11299, stintNumber: 3, driverNumber: 1, lapStart: 53, lapEnd: 78, compound: "SOFT", tyreAgeAtStart: 0)
            ], timeDelta: 2.3)
        ]

        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubbleView(message: message, viewModel: viewModel)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
            .navigationTitle("Strategy Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
        }
    }
}

struct DeltaPoint {
    let lap: Int
    let delta: Double
}

#Preview {
    StrategyAssistantPreviewWrapper()
}
