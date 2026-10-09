//
//  AppAssistantTranslator.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//


import Foundation
import FoundationModels
import Combine

enum LiveF1Constraints {
    static var trackNames: [String] = []
}

@MainActor
class AppAssistantTranslator: ObservableObject {
    @Published var isThinking: Bool = false
    @Published var error: String? = nil
    @Published var pendingCards: [AssistantCardContent] = []

    let selectionCoordinator = SessionSelectionCoordinator()

    private let model = SystemLanguageModel.default
    private var lastSelectedDriverName: String = ""
    private var lastEvaluationFailed = false
    
    private struct ConversationTurn {
        let userText: String
        let assistantText: String
    }

    private var history: [ConversationTurn] = []
    private let maxHistoryTurns = 3
    private let maxCharsPerTurn = 220
    private var lastCategories: ToolCategories = []

    func respond(
        to prompt: String,
        sessionStore: CurrentSessionStore,
        championshipStore: ChampionshipDataStore,
        fiaStore: FIADocumentStore
    ) async -> String? {
        isThinking = true
        error = nil
        pendingCards = []
        lastEvaluationFailed = false
        defer { isThinking = false }

        guard model.isAvailable else {
            error = "Apple Intelligence is not available on this device"
            return nil
        }

        if let allSessions = try? await F1PredictorSessionParser.fetchRaces(year: 2026, sessionType: "Race") {
            LiveF1Constraints.trackNames = Array(Set(allSessions.map { $0.circuitShortName })).sorted()
        }

        let categories = classify(prompt)
        lastCategories = categories

        var tools: [any Tool] = []
        var instructionSections: [String] = []

        if categories.contains(.championship) {
            tools.append(GetDriverStandingsTool(store: championshipStore) { [weak self] _, result in
                Task { @MainActor in self?.pendingCards.append(.standings(result)) }
            })
            tools.append(GetConstructorStandingsTool(store: championshipStore) { [weak self] _, result in
                Task { @MainActor in self?.pendingCards.append(.constructorStandings(result)) }
            })
            tools.append(GetScheduleTool(store: championshipStore) { [weak self] _, result in
                Task { @MainActor in self?.pendingCards.append(.schedule(result)) }
            })
            tools.append(GetRaceResultsTool(store: championshipStore) { [weak self] _, result in
                Task { @MainActor in self?.pendingCards.append(.raceResults(result)) }
            })
            tools.append(SelectSessionTool(store: championshipStore, coordinator: selectionCoordinator))

            instructionSections.append("""
            Championship questions — use getDriverStandings, getConstructorStandings, getSchedule (next weekend by default, or a given round), or getRaceResults. Only call selectSession if it's genuinely ambiguous which race/session is meant — not for "the next race."
            """)
        }

        if categories.contains(.strategy) {
            tools.append(LoadRaceForStrategyTool(sessionStore: sessionStore))

            tools.append(SelectDriverForStrategyTool(sessionStore: sessionStore) { [weak self] result in
                Task { @MainActor in
                    self?.lastSelectedDriverName = result.selectedDriverName
                }
            })

            tools.append(EvaluatePitStrategyTool(sessionStore: sessionStore) { [weak self] finalHypoStints, result in
                Task { @MainActor in
                    self?.lastEvaluationFailed = !result.success
                    guard result.success else { return }
                    guard let vm = sessionStore.raceViewModel, let driver = vm.selectedDriverNumber else { return }
                    self?.pendingCards.append(.strategy(
                        driverNumber: driver,
                        driverName: self?.lastSelectedDriverName ?? "#\(driver)",
                        actual: vm.stintsForSelectedDriver,
                        hypothetical: finalHypoStints,
                        timeDelta: result.deltaVsActualSeconds
                    ))
                }
            })

            instructionSections.append("""
            Strategy "what if" questions — always in this order (do NOT call getSchedule for these, even though a race/track name is mentioned):
               a. loadRaceForStrategy → totalLaps, driverRoster.
               b. selectDriverForStrategy — pass the driver name as the user wrote it, verbatim. Returns the resolved driver, actualPitLaps, actualCompounds, and strategyTemplatesObserved — use these directly, don't guess.
               c. evaluatePitStrategy — describe the change; the app applies it to the driver's real strategy. You never copy or rewrite pit lap arrays for edits.

                  requestType editExisting + edits (applied in order):
                    - shiftStop(stop, laps): "pit 5 laps later" → laps 5. "3 laps earlier" → laps -3. An undercut is negative laps, an overcut is positive.
                    - addStop(atLap, compound), removeStop(stop), setCompound(stint, compound).
                    - `stop` is a stop NUMBER (1 = first stop, 2 = second), never a lap number. If the driver made only one stop, omit it.
                    - "More aggressive undercut" → shiftStop with negative laps, optionally plus setCompound to a softer tyre.

                    requestType freshPlan — ONLY when the user asks for a different number of stops ("one stop", "two-stop", "three stop"). Set stopCount; the app chooses the pit laps. Only fill freshCompounds (stopCount + 1 tyres) if a strategyTemplatesObserved entry for that stop count suggests specific compounds; otherwise leave it empty.

               evaluatePitStrategy returns structuralDiff — the actual computed difference from the driver's real race. Before replying, check it matches what the user asked for:
               - Empty diff, a missing requested change, or an unrequested change → correct the call and evaluate again.
               Never state a time delta that didn't come from a structuralDiff you've verified this way.

               If evaluatePitStrategy returns an error, silently fix the call using the error text and try again — don't explain the failure or ask permission. Only reply once you have a verified success.
            """)
        }

        if categories.contains(.racePace) {
            tools.append(GetRacePaceTool(sessionStore: sessionStore) { [weak self] focused, all, result in
                Task { @MainActor in self?.pendingCards.append(.racePace(focusedStats: focused, allStats: all, result: result)) }
            })

            instructionSections.append("""
            Race pace questions — call getRacePace directly with raceQuery/sessionType (same identifiers as loadRaceForStrategy). Do not call loadRaceForStrategy first for these. Set filterToSpecificDrivers to true only if the user named specific drivers, and only then pass names (as written, never numbers) in driverNames — leave both at their defaults for general questions like "who was fastest". recentFormOnly: true for "right now"/"recently", false for whole-race questions.

               No tool returns team rosters — for team-based comparisons ("the two Red Bulls"), ask the user which drivers they mean rather than guessing a lineup.
            """)
        }
        
//        if categories.contains(.racePace) {
//            tools.append(LoadRaceForStrategyTool(sessionStore: sessionStore))
//
//            tools.append(GetRacePaceTool(sessionStore: sessionStore) { [weak self] focused, all, result in
//                Task { @MainActor in self?.pendingCards.append(.racePace(focusedStats: focused, allStats: all, result: result)) }
//            })
//
//            instructionSections.append("""
//            Race pace questions — call getRacePace directly with raceQuery/sessionType (same identifiers as loadRaceForStrategy) and optional driverNames (names as written, never numbers — it resolves them itself). ONLY provide a non-empty driverNumbers to race pace tool if user specifies their name or number, pass an empty array for general questions like who was fastest. Do not call loadRaceForStrategy first for these. recentFormOnly: true for "right now"/"recently", false for whole-race questions.
//
//               No tool returns team rosters — for team-based comparisons ("the two Red Bulls"), ask the user which drivers they mean rather than guessing a lineup.
//            """)
//        }
        
        if categories.contains(.fiaDocs) {
            tools.append(GetFIADocumentsTool(store: fiaStore) { [weak self] docs, result in                Task { @MainActor in self?.pendingCards.append(.fiaDocuments(documents: docs, result: result)) }
            })

            instructionSections.append("""
            Penalty / steward questions — call getFIADocuments directly with optional driverNames (names as written, never numbers — it resolves them itself). Do not call loadRaceForStrategy first. readDetails: true for "why was he penalized?" or "what happened with X?", false for "any penalties?" or "what's under investigation?". It only covers the current race weekend. Always say which driver it matched. If it finds nothing, say no documents were found as of the time given; never say there was no penalty.
            """)
        }

        if categories.contains(.laps) {
            tools.append(GetLapsTool { [weak self] laps, result in
                Task { @MainActor in self?.pendingCards.append(.laps(laps: laps, result: result)) }
            })

            instructionSections.append("""
            Lap time questions — call getLaps directly with raceQuery/sessionType. Do not call loadRaceForStrategy first. "Pole" = sessionType Qualifying (Sprint Qualifying for sprint pole), fastestCount 1, no drivers. "Fastest lap of the race" = sessionType Race, fastestCount 1. Set filterToSpecificDrivers to true only if the user named drivers, and only then pass names as written in driverNames. "All of X's laps" = fastestCount 0 with that driver named. "Top 10 in qualifying" = bestLapPerDriver true, fastestCount 10. Always say which driver set the lap and on which lap number, and report lap times exactly as returned in lapTime. If the result note says the full list is in a card, summarize briefly instead of listing every lap.
            """)
        }
        
        let numberedSections = instructionSections.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n\n")

        let instructions = """
        You are the LiveF1 assistant.

        \(numberedSections)

        Never guess anything a tool can tell you — driver numbers, standings, dates, results, or strategy outcomes — always read it from a tool result. Keep answers concise.
        \(recentContextBlock())
        """
        
//        var tools: [any Tool] = []
//
//        tools.append(LoadRaceForStrategyTool(sessionStore: sessionStore))
//
//        tools.append(SelectDriverForStrategyTool(sessionStore: sessionStore) { [weak self] result in
//            Task { @MainActor in
//                self?.lastSelectedDriverName = result.selectedDriverName
//            }
//        })
//        
//        tools.append(EvaluatePitStrategyTool(sessionStore: sessionStore) { [weak self] finalHypoStints, result in
//            Task { @MainActor in
//                self?.lastEvaluationFailed = !result.success
//                guard result.success else { return }
//                guard let vm = sessionStore.raceViewModel, let driver = vm.selectedDriverNumber else { return }
//                self?.pendingCards.append(.strategy(
//                    driverNumber: driver,
//                    driverName: self?.lastSelectedDriverName ?? "#\(driver)",
//                    actual: vm.stintsForSelectedDriver,
//                    hypothetical: finalHypoStints,
//                    timeDelta: result.deltaVsActualSeconds
//                ))
//            }
//        })
//        
//        tools.append(GetRacePaceTool(sessionStore: sessionStore) { [weak self] focused, all, result in
//            Task { @MainActor in self?.pendingCards.append(.racePace(focusedStats: focused, allStats: all, result: result)) }
//        })
//        
//        tools.append(GetDriverStandingsTool(store: championshipStore) { [weak self] _, result in
//            Task { @MainActor in self?.pendingCards.append(.standings(result)) }
//        })
//
//        tools.append(GetConstructorStandingsTool(store: championshipStore) { [weak self] _, result in
//            Task { @MainActor in self?.pendingCards.append(.constructorStandings(result)) }
//        })
//
//        tools.append(GetScheduleTool(store: championshipStore) { [weak self] _, result in
//            Task { @MainActor in self?.pendingCards.append(.schedule(result)) }
//        })
//
//        tools.append(GetRaceResultsTool(store: championshipStore) { [weak self] _, result in
//            Task { @MainActor in self?.pendingCards.append(.raceResults(result)) }
//        })
//
//        tools.append(SelectSessionTool(store: championshipStore, coordinator: selectionCoordinator))
//
//        let instructions = """
//        You are the LiveF1 assistant.
//
//        1. Championship questions — use getDriverStandings, getConstructorStandings, getSchedule (next weekend by default, or a given round), or getRaceResults. Only call selectSession if it's genuinely ambiguous which race/session is meant — not for "the next race."
//
//        2. Strategy "what if" questions — always in this order (do NOT call getSchedule for these, even though a race/track name is mentioned):
//           a. loadRaceForStrategy → totalLaps, driverRoster.
//           b. selectDriverForStrategy — pass the driver name as the user wrote it, verbatim. Returns the resolved driver, actualPitLaps, actualCompounds, and strategyTemplatesObserved — use these directly, don't guess.
//
//           c. evaluatePitStrategy — provide pitLaps (ascending list of pit laps) and compounds (exactly pitLaps.count + 1 entries, one more than the number of stops). Two kinds of request:
//
//              DELTA request ("move the Nth stop X laps earlier/later") — copy actualPitLaps and actualCompounds verbatim, then change exactly ONE number. Never add, remove, or reorder entries for a delta request.
//                Worked examples (actualPitLaps: [3, 28], actualCompounds: [SOFT, MEDIUM, HARD]):
//                - "second stop 5 laps earlier" → pitLaps: [3, 23], compounds: [SOFT, MEDIUM, HARD]  (only index 1 changed: 28-5=23)
//                - "second stop 5 laps later"   → pitLaps: [3, 33], compounds: [SOFT, MEDIUM, HARD]  (only index 1 changed: 28+5=33)
//                - "first stop 2 laps earlier"  → pitLaps: [1, 28], compounds: [SOFT, MEDIUM, HARD]  (only index 0 changed: 3-2=1)
//
//              STOP-COUNT request ("one stop", "three stop") — build FRESH pit laps from scratch, do not reuse actualPitLaps's values. Check strategyTemplatesObserved first for a template matching the requested stop count and base your pit laps/compounds on it; if none exists, space pit laps evenly across totalLaps.
//                Worked examples (totalLaps: 53, actual is 1-stop [3, 28] with 2 stints):
//                - "one stop"   → pitLaps: [27], compounds: [MEDIUM, HARD]  (1 pit lap, 2 compounds)
//                - "three stop" → pitLaps: [13, 27, 40], compounds: [SOFT, MEDIUM, MEDIUM, HARD]  (3 fresh pit laps evenly spaced, 4 compounds)
//
//              Rule that always holds: pitLaps.count must equal compounds.count - 1. Set changeSummary to state the exact arithmetic or template you used, e.g. "actualPitLaps[1] = 28, requested +5, new value = 33" or "built a fresh 3-stop from evenly spaced laps since no 3-stop template existed."
//
//           evaluatePitStrategy returns structuralDiff — the actual computed difference from the driver's real race. Before replying:
//           - Empty diff → you evaluated the unchanged actual strategy. Rebuild and re-evaluate.
//           - Diff missing the requested change, or containing changes not requested → rebuild and re-evaluate.
//           Never present a result, or state a time delta, that didn't come from a structuralDiff you've verified this way.
//
//           If evaluatePitStrategy errors or rejects your input, silently correct pitLaps/compounds and call it again — don't explain the failure or ask permission. Only reply once you have a verified success.
//        
//        3. Race pace questions — call getRacePace directly with raceQuery/sessionType (same
//           identifiers as loadRaceForStrategy) and optional driverNames (names as written,
//           never numbers — it resolves them itself). Do not call loadRaceForStrategy first
//           for these. recentFormOnly: true for "right now"/"recently", false for whole-race
//           questions.
//
//           No tool returns team rosters — for team-based comparisons ("the two Red Bulls"),
//           ask the user which drivers they mean rather than guessing a lineup.
//
//        Never guess anything a tool can tell you — driver numbers, standings, dates, results, or strategy outcomes — always read it from a tool result. Keep answers concise.
//        """

        do {
//            let session = LanguageModelSession(tools: tools, instructions: instructions)
//            var response = try await session.respond(to: prompt)
//            var attempts = 0
//            while lastEvaluationFailed && pendingCards.isEmpty && attempts < 2 {
//                attempts += 1
//                lastEvaluationFailed = false
//                response = try await session.respond(to: "That strategy didn't change anything or was rejected. Build a genuinely different hypotheticalStints and call evaluateStrategy again — don't explain, just retry.")
//            }
//            return response.content
            
            var currentPrompt = prompt
            var attempts = 0
            var response: LanguageModelSession.Response<String>? = nil

            repeat {
                let session = LanguageModelSession(tools: tools, instructions: instructions)
                lastEvaluationFailed = false
                response = try await session.respond(to: currentPrompt)   // no `?` — let real errors propagate
                attempts += 1
                if lastEvaluationFailed && !pendingCards.contains(where: { if case .strategy = $0 { return true }; return false }) && attempts < 3 {
                    currentPrompt = "\(prompt) — your last attempt was rejected, try a genuinely different pitLaps/compounds."
                } else {
                    break
                }
            } while true

            if let text = response?.content {
                history.append(ConversationTurn(userText: prompt, assistantText: text))
                if history.count > maxHistoryTurns {
                    history.removeFirst(history.count - maxHistoryTurns)
                }
            }
            return response?.content        } catch {
            self.error = "Sorry, an error occurred, please retry your question: \(error.localizedDescription)"
            return nil
        }
    }
    
    private func recentContextBlock() -> String {
        guard !history.isEmpty else { return "" }
        let lines = history.suffix(maxHistoryTurns).map { turn -> String in
            let u = String(turn.userText.prefix(maxCharsPerTurn))
            let a = String(turn.assistantText.prefix(maxCharsPerTurn))
            return "User: \(u)\nAssistant: \(a)"
        }
        return """

        Recent conversation — use this ONLY to resolve references like "him" or "what about X", \
        never as a source of facts. If a driver or track isn't specified, assume its the same as the last message Always call a tool fresh for any number, name, or result:
        \(lines.joined(separator: "\n"))
        """
    }

    func resetConversation() {
        history.removeAll()
        lastCategories = []
    }

    struct ToolCategories: OptionSet {
        let rawValue: Int
        static let strategy      = ToolCategories(rawValue: 1 << 0)
        static let racePace      = ToolCategories(rawValue: 1 << 1)
        static let championship  = ToolCategories(rawValue: 1 << 2)
        static let fiaDocs       = ToolCategories(rawValue: 1 << 3)
        static let laps          = ToolCategories(rawValue: 1 << 4)
        static let all: ToolCategories = [.strategy, .racePace, .championship, .laps]
    }

    private func classify(_ prompt: String) -> ToolCategories {
        let p = prompt.lowercased()
        var categories: ToolCategories = []

        let strategyKeywords = ["pit", "stop", "strategy", "what if", "stint", "undercut", "overcut", "compound", "tyre", "tire"]
        let paceKeywords = ["pace", "quickest", "quicker", "slower", "faster", "fastest"]
        let lapKeywords = ["pole", "fastest lap", "best lap", "quickest lap", "lap time", "laptime", "every lap", "all laps", "each lap", "quali", "practice"]
        let champKeywords = ["standing", "points", "schedule", "result", "championship", "next race", "last race", "who won", "session", "finish", "podium", "when is"]
        let fiaKeywords = ["penalt", "penaliz", "penalis", "investigat", "steward", "infringement", "disqualif", "reprimand", "punish", "fia doc", "unsafe release", "track limits"]

        if strategyKeywords.contains(where: { p.contains($0) }) { categories.insert(.strategy) }
        if paceKeywords.contains(where: { p.contains($0) }) { categories.insert(.racePace) }
        if lapKeywords.contains(where: { p.contains($0) }) { categories.insert(.laps) }
        if champKeywords.contains(where: { p.contains($0) }) { categories.insert(.championship) }
        if fiaKeywords.contains(where: { p.contains($0) }) { categories.insert(.fiaDocs) }

        // "fastest lap" / "fastest in quali" should go to getLaps, not the pace tool,
        // unless the user actually said "pace".
        if categories.contains(.laps) && !p.contains("pace") {
            categories.remove(.racePace)
        }

        if categories.isEmpty {
            // No new keywords — likely a short follow-up ("what about at Silverstone?").
            // Stick with whatever we were just doing rather than paying to load everything.
            return lastCategories.isEmpty ? .all : lastCategories
        }
        return categories
    }
}

//
//import Foundation
//import FoundationModels
//import Combine
//
//enum LiveF1Constraints {
//    static var trackNames: [String] = []
//}
//
//@MainActor
//class AppAssistantTranslator: ObservableObject {
//    @Published var isThinking: Bool = false
//    @Published var error: String? = nil
//    @Published var pendingCards: [AssistantCardContent] = []
//
//    let selectionCoordinator = SessionSelectionCoordinator()
//
//    private let model = SystemLanguageModel.default
//
//    func respond(
//        to prompt: String,
//        sessionStore: CurrentSessionStore,
//        championshipStore: ChampionshipDataStore
//    ) async -> String? {
//        isThinking = true
//        error = nil
//        pendingCards = []
//        defer { isThinking = false }
//
//        guard model.isAvailable else {
//            error = "Apple Intelligence is not available on this device"
//            return nil
//        }
//        
//        if let allSessions = try? await F1PredictorSessionParser.fetchRaces(year: 2026, sessionType: "Race") {
//            LiveF1Constraints.trackNames = Array(Set(allSessions.map { $0.circuitShortName })).sorted()
//        }
//
//        var tools: [any Tool] = []
//        
//        tools.append(LoadRaceForStrategyTool(sessionStore: sessionStore))
//        tools.append(SelectDriverForStrategyTool(sessionStore: sessionStore))
//
//        tools.append(EvaluateStrategyTool(sessionStore: sessionStore) { [weak self] args, result in
//            guard result.success else { return }
//            Task { @MainActor in
//                guard let vm = sessionStore.raceViewModel, let driver = vm.selectedDriverNumber else { return }
//                let hypoStints = args.hypotheticalStints.enumerated().map { i, stint in
//                    F1PredictorStint(
//                        meetingKey: 0, sessionKey: 0, stintNumber: i + 1,
//                        driverNumber: driver,
//                        lapStart: stint.lapStart, lapEnd: stint.lapEnd,
//                        compound: stint.compound, tyreAgeAtStart: 0
//                    )
//                }
//                self?.pendingCards.append(.strategy(
//                    actual: vm.stintsForSelectedDriver,
//                    hypothetical: hypoStints,
//                    timeDelta: result.deltaVsActualSeconds
//                ))
//            }
//        })
//
//        tools.append(GetDriverStandingsTool(store: championshipStore) { [weak self] _, result in
//            Task { @MainActor in self?.pendingCards.append(.standings(result)) }
//        })
//
//        tools.append(GetConstructorStandingsTool(store: championshipStore) { [weak self] _, result in
//            Task { @MainActor in self?.pendingCards.append(.constructorStandings(result)) }
//        })
//
//        tools.append(GetScheduleTool(store: championshipStore) { [weak self] _, result in
//            Task { @MainActor in self?.pendingCards.append(.schedule(result)) }
//        })
//
//        tools.append(GetRaceResultsTool(store: championshipStore) { [weak self] _, result in
//            Task { @MainActor in self?.pendingCards.append(.raceResults(result)) }
//        })
//
//        tools.append(SelectSessionTool(store: championshipStore, coordinator: selectionCoordinator))
//
////        let instructions = """
////        You are the LiveF1 assistant. You can answer:
////        1. Championship questions — getDriverStandings for driver points/rankings, getConstructorStandings for team standings, getSchedule for a race weekend's full session schedule (next weekend by default, or a given round), getRaceResults for a past round's finishing order. If it's genuinely ambiguous which race or session the user means, call selectSession to let them pick — do not use it for single-answer questions like "the next race."
////        2. Race strategy "what if" questions — if no race is loaded yet, or the user is asking about a different race than what's currently loaded, call loadRaceForStrategy first. Then use evaluateStrategy to check any hypothetical stint sequence before stating a time delta. Never state a time delta you didn't get from evaluateStrategy.
////
////        Pick whichever tool(s) fit the question. Never guess standings, points, dates, results, or strategy outcomes. Keep answers concise.
////        """
////        let instructions = """
////        You are the LiveF1 assistant. You can answer:
////        1. Championship questions — getDriverStandings for driver points/rankings, getConstructorStandings for team standings, getSchedule for a race weekend's full session schedule (next weekend by default, or a given round), getRaceResults for a past round's finishing order. If it's genuinely ambiguous which race or session the user means, call selectSession to let them pick — do not use it for single-answer questions like "the next race."
////        2. Race strategy "what if" questions — for these, follow this exact sequence:
////           a. loadRaceForStrategy — loads the race, returns totalLaps and driverRoster.
////           b. selectDriverForStrategy — driverRoster returned by loadRaceForStrategy lists "number: full name" for every driver in that session. Match the user's requested driver against these names, then pass the corresponding NUMBER to selectDriverForStrategy. Never guess a driver's number from memory — always read it off driverRoster. This returns totalLaps and the driver's actualStints — use these directly, don't guess.
////           c. evaluateStrategy — build hypothetical stints reflecting the requested strategy and evaluate.
////
////        Before calling evaluateStrategy, decide what kind of change was requested:
////        - A stop-count request ("one stop", "two stop", "no stops") — build hypotheticalStints from scratch with exactly that many stops. Do not copy actualStints's lap boundaries.
////        - A delta request ("5 laps earlier", "extend the middle stint", "switch to hards sooner") — start from the driver's actualStints and apply only the described change, keeping every other boundary and compound the same.
////
////        Fill in changeSummary to describe which kind of request this is and exactly what you changed. Make sure hypotheticalStints actually matches what changeSummary describes — if you say "one stop," hypotheticalStints must have exactly 2 stints; if you say "5 laps earlier," only the relevant boundary should differ from actualStints.
////        
////        evaluateStrategy returns computed facts about what you evaluated: stopCountEvaluated, compoundsUsed, and identicalToActualStrategy. Before presenting a result to the user, check these facts against their original request:
////        - If identicalToActualStrategy is true but the user asked for any kind of change, you built the wrong strategy — regenerate hypotheticalStints to actually reflect the change requested, and call evaluateStrategy again.
////        - If stopCountEvaluated doesn't match a stop count the user explicitly asked for, regenerate and try again.
////        - For requests that aren't about stop count (timing, compound choice, etc.), verify compoundsUsed and the lap boundaries you generated actually reflect the request.
////        Do not present a result to the user until what you evaluated genuinely matches what they asked.
////
////        evaluateStrategy returns structuralDiff — the actual, computed differences between what you evaluated and the driver's real race. Before presenting a result, check structuralDiff against the user's request:
////        - If structuralDiff is empty, you evaluated the actual strategy unchanged — regenerate.
////        - If structuralDiff shows changes the user didn't ask for, or doesn't show the change they did ask for, regenerate.
////        This applies to every kind of request — stop count, timing, or compound — not just stop count.
////
////        Use compounds: SOFT, MEDIUM, HARD, INTERMEDIATE, WET.
////        
////        If evaluateStrategy returns an error or rejects your hypothetical, do not explain the mistake to the user or ask if you should try again — immediately build a corrected hypotheticalStints sequence yourself and call evaluateStrategy again in the same turn. Only respond to the user once you have a successful result.
////
////        If any step fails, read the error and correct your next call — don't guess or skip a step.
////        Never state a time delta you didn't get from a successful evaluateStrategy call.
////        Pick whichever tool(s) fit the question. Never guess standings, points, dates, results, or strategy outcomes. Keep answers concise.
////        """
//        let instructions = """
//        You are the LiveF1 assistant.
//
//        1. Championship questions — use getDriverStandings, getConstructorStandings, getSchedule (next weekend by default, or a given round), or getRaceResults. Only call selectSession if it's genuinely ambiguous which race/session is meant — not for "the next race."
//
//        2. Strategy "what if" questions — always in this order:
//           a. loadRaceForStrategy → totalLaps, driverRoster ("number: name").
//           b. selectDriverForStrategy — match the user's driver against driverRoster and pass that NUMBER. Returns actualStints — use as-is.
//           c. evaluateStrategy — build hypotheticalStints for the requested change:
//              - Stop-count request ("one stop", "two stop") → build from scratch with exactly that many stints. Do not copy actualStints's boundaries.
//              - Delta request ("5 laps earlier", "switch to hards sooner") → start from actualStints, change only the described boundary/compound.
//           Set changeSummary to match hypotheticalStints exactly (e.g. "one stop" ⇒ exactly 2 stints).
//
//           evaluateStrategy returns structuralDiff, the actual computed difference from the driver's real race. Before replying:
//           - Empty diff → you evaluated the unchanged actual strategy. Rebuild and re-evaluate.
//           - Diff missing the requested change, or containing changes not requested → rebuild and re-evaluate.
//           Never present a result, or state a time delta, that didn't come from a structuralDiff you've verified this way.
//
//           If evaluateStrategy errors or rejects your hypothetical, silently correct hypotheticalStints and call it again — don't explain the failure or ask permission. Only reply once you have a verified success.
//
//        Never guess anything a tool can tell you — driver numbers, standings, dates, results, or strategy outcomes — always read it from a tool result. Keep answers concise.
//        """
//
//        do {
//            let session = LanguageModelSession(tools: tools, instructions: instructions)
//            let response = try await session.respond(to: prompt)
//            return response.content
//        } catch {
//            self.error = error.localizedDescription
//            return nil
//        }
//    }
//}
