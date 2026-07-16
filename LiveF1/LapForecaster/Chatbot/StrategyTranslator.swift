//
//  StrategyResponse.swift
//  LiveF1
//
//  Created by Riley Koo on 6/15/26.
//

import Foundation
import FoundationModels
import Combine

@Generable
struct StrategyResponse {
    @Guide(description: "Ordered list of stints for the hypothetical strategy, must cover all laps with no gaps")
    var stints: [GeneratedStint]
}

@Generable
struct GeneratedStint {
    @Guide(description: "Tyre compound: SOFT, MEDIUM, HARD, INTERMEDIATE, or WET")
    var compound: String
    @Guide(description: "Lap number this stint starts on, first stint must be 1")
    var lapStart: Int
    @Guide(description: "Lap number this stint ends on, last stint must equal total laps")
    var lapEnd: Int
}

@MainActor
class StrategyTranslator: ObservableObject {
    @Published var isThinking: Bool = false
    @Published var error: String? = nil
    @Published var lastEvaluation: EvaluateStrategyResult? = nil
    @Published var toolCallLog: [(arguments: EvaluateStrategyArguments, result: EvaluateStrategyResult)] = []

    private let model = SystemLanguageModel.default

    func translate(
        prompt: String,
        context: StrategyContext,
        median: Double,
        trackModel: TrackEvolutionCalculator.TrackEvolutionModel,
        annotatedLaps: [AnnotatedLap]
    ) async -> [F1PredictorStint]? {
        isThinking = true
        error = nil
        lastEvaluation = nil
        defer { isThinking = false }

        guard model.isAvailable else {
            error = "Apple Intelligence is not available on this device"
            return nil
        }

        let tool = EvaluateStrategyTool(
            context: context,
            median: median,
            trackModel: trackModel,
            annotatedLaps: annotatedLaps,
            onResult: { [weak self] args, result in
                Task { @MainActor in
                    self?.toolCallLog.append((args, result))
                    self?.lastEvaluation = result
                }
            }
        )

        do {
            let session = LanguageModelSession(
                tools: [tool],
                instructions: context.systemPrompt() +
                    "\nBefore finalizing your answer, call evaluateStrategy on the candidate stint sequence to get its real time delta. Never state a time delta you didn't get from evaluateStrategy."
            )
            let response = try await session.respond(
                to: prompt,
                generating: StrategyResponse.self
            )
            return convert(response.content.stints, context: context)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    private func convert(
        _ generated: [GeneratedStint],
        context: StrategyContext
    ) -> [F1PredictorStint] {
        generated.enumerated().map { index, stint in
            F1PredictorStint(
                meetingKey: 0,
                sessionKey: 0,
                stintNumber: index + 1,
                driverNumber: context.selectedDriver,
                lapStart: stint.lapStart,
                lapEnd: stint.lapEnd,
                compound: stint.compound,
                tyreAgeAtStart: 0
            )
        }
    }
}
