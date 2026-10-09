//
//  EvaluatePitStrategyTool.swift
//  Redline
//
//  Created by Riley Koo on 9/10/26.
//

import Foundation
import FoundationModels
import Combine

// MARK: - Edit vocabulary
//
// The model describes *what to change*; Swift applies the edits to the driver's real
// strategy. The model never has to copy or rewrite an array for non-fresh requests.

@Generable
enum StrategyEditKind {
    case shiftStop      // move an existing stop earlier/later ("5 laps later", undercut, overcut)
    case addStop        // add an extra stop
    case removeStop     // skip an existing stop
    case setCompound    // change the tyre for one stint
}

@Generable
struct StrategyEdit {
    @Guide(description: "shiftStop: move an existing stop (use for 'pit N laps later/earlier', undercut, overcut, extend a stint). addStop: add an extra stop. removeStop: skip an existing stop. setCompound: change the tyre of one stint.")
    var kind: StrategyEditKind

    @Guide(description: "shiftStop / removeStop: stop NUMBER, not a lap number. First stop = 1, second = 2. Omit it if the driver made only one stop.")
    var stop: Int?

    @Guide(description: "shiftStop only: laps to move the stop. Positive = later, negative = earlier. An undercut is negative. '5 laps later' = 5.")
    var laps: Int?

    @Guide(description: "addStop only: the lap number to pit on.")
    var atLap: Int?

    @Guide(description: "setCompound only: which stint, 1-based (first stint = 1).")
    var stint: Int?

    @Guide(description: "addStop: the tyre fitted at the new stop. setCompound: the new tyre for that stint. One of SOFT, MEDIUM, HARD.")
    var compound: String?
}

// MARK: - Tool arguments / result

@Generable
enum StrategyRequestType {
    case editExisting   // "pit 5 laps later", "undercut", "swap to softs", "skip the second stop"
    case freshPlan      // "one stop", "three stop" — a wholly different plan
}

@Generable
struct EvaluatePitStrategyArguments {
    @Guide(description: "editExisting: any tweak to the driver's real strategy (move a stop, change a tyre, add/skip a stop). freshPlan: ONLY when the user asks for a different number of stops, like 'one stop' or 'three stop'.")
    var requestType: StrategyRequestType

    @Guide(description: "Used only when requestType is editExisting, otherwise leave empty. Edits are applied IN ORDER to the driver's real strategy. You do NOT need to know or copy the pit laps; just describe the change.", .maximumCount(4))
    var edits: [StrategyEdit]

    @Guide(description: "Used only when requestType is freshPlan: the number of stops requested ('two-stop' = 2). The app chooses the pit laps. Use 1 when requestType is editExisting.", .range(1...4))
    var stopCount: Int

    @Guide(description: "Used only when requestType is freshPlan, and only if a strategyTemplatesObserved entry for this stop count suggests specific tyres: stopCount + 1 compounds (SOFT, MEDIUM, HARD), one per stint. Otherwise leave empty and the app picks.", .maximumCount(5))
    var freshCompounds: [String]
}

@Generable
struct EvaluatePitStrategyResult: Sendable {
    var success: Bool
    var errorMessage: String?
    var totalRaceTimeSeconds: Double?
    var deltaVsActualSeconds: Double?
    var stopCountEvaluated: Int?
    var compoundsUsed: [String]?
    var identicalToActualStrategy: Bool
    var structuralDiff: [String]
    var baselinePitLaps: [Int]?
    var appliedPitLaps: [Int]?
}

enum EvaluatePitStrategyError: LocalizedError {
    case noRaceLoaded, noDriverSelected, insufficientData

    var errorDescription: String? {
        switch self {
        case .noRaceLoaded: return "No race is loaded yet. Call loadRaceForStrategy first."
        case .noDriverSelected: return "No driver is selected. Call selectDriverForStrategy first."
        case .insufficientData: return "Not enough lap data to evaluate this strategy yet."
        }
    }
}

private struct PlanError: Error {
    let message: String
}

// MARK: - Tool

@MainActor
struct EvaluatePitStrategyTool: Tool {
    let name = "evaluatePitStrategy"
    let description = "Evaluates a what-if pit strategy for the selected driver. For changes to the real strategy, pass `edits` (shiftStop, addStop, removeStop, setCompound); they are applied to the driver's actual plan for you. For a wholly new plan like 'one stop', pass freshPitLaps + freshCompounds instead. Returns total race time, delta vs. the actual race, and a structural diff. Requires a race and driver to already be selected. Always call this before stating a time delta."

    let sessionStore: CurrentSessionStore
    let onResult: @Sendable ([F1PredictorStint], EvaluatePitStrategyResult) -> Void

    func call(arguments: EvaluatePitStrategyArguments) async throws -> EvaluatePitStrategyResult {
//        print(arguments)
        guard let vm = sessionStore.raceViewModel else {
            throw EvaluatePitStrategyError.noRaceLoaded
        }
        guard let driver = vm.selectedDriverNumber else {
            throw EvaluatePitStrategyError.noDriverSelected
        }
        guard let median = vm.driverMedianLapTime,
              let trackModel = vm.trackEvolutionModel,
              !vm.annotatedLaps.isEmpty
        else {
            print("GUARD FAILED — median: \(vm.driverMedianLapTime != nil), trackModel: \(vm.trackEvolutionModel != nil), laps: \(vm.annotatedLaps.count)")
            throw EvaluatePitStrategyError.insufficientData
        }

        let totalLaps = vm.laps.filter { $0.driverNumber == driver }.map { $0.lapNumber }.max() ?? 0

        // Baseline comes from app state, never from the model.
        let context = StrategyContextBuilder.build(
            session: vm.session, laps: vm.laps, stints: vm.stints, selectedDriver: driver
        )
        let actualStints = context.selectedDriverStints
        let baselinePits = actualStints.dropLast().compactMap { $0.lapEnd }
        let baselineCompounds = actualStints.map { ($0.compound ?? "MEDIUM").uppercased() }

        let baselineNote = "Driver's actual strategy: pitLaps \(baselinePits), compounds \(baselineCompounds), race length \(totalLaps) laps."

        func failure(_ message: String, applied: [Int]? = nil) -> EvaluatePitStrategyResult {
            EvaluatePitStrategyResult(
                success: false,
                errorMessage: "\(message) \(baselineNote) Fix and call evaluatePitStrategy again.",
                totalRaceTimeSeconds: nil, deltaVsActualSeconds: nil,
                stopCountEvaluated: nil, compoundsUsed: nil,
                identicalToActualStrategy: false, structuralDiff: [],
                baselinePitLaps: baselinePits, appliedPitLaps: applied
            )
        }

        // MARK: Build the candidate plan

        var pitLaps = baselinePits
        var compounds = baselineCompounds

        // requestType decides which fields count; the other group is ignored, so the model
        // can't produce a conflicting plan by filling both.
        switch arguments.requestType {
        case .freshPlan:
            // Swift builds the plan; the model only supplies the stop count (and optionally tyres),
            // so it can never generate a runaway pit-lap array.
            let n = arguments.stopCount
            guard (1...4).contains(n), totalLaps > n + 1 else {
                return failure("stopCount \(n) is not usable for a \(totalLaps)-lap race. Use 1 to 4.")
            }
            pitLaps = (1...n).map { totalLaps * $0 / (n + 1) }
            if arguments.freshCompounds.count == n + 1 {
                compounds = arguments.freshCompounds.map { $0.uppercased() }
            } else {
                // Default: follow the actual race's tyre order, then repeat its last compound.
                let fallback = baselineCompounds.last ?? "MEDIUM"
                compounds = (0...n).map { $0 < baselineCompounds.count ? baselineCompounds[$0] : fallback }
            }
        case .editExisting:
            guard !arguments.edits.isEmpty else {
                return failure("requestType is editExisting, so `edits` must contain at least one edit.")
            }
            do {
                (pitLaps, compounds) = try Self.apply(arguments.edits, pits: pitLaps, compounds: compounds)
            } catch let e as PlanError {
                return failure(e.message)
            }
        }

        // MARK: Validate (exact, cheap)

        guard compounds.count == pitLaps.count + 1 else {
            return failure("compounds must have exactly \(pitLaps.count + 1) entries (pitLaps.count + 1), got \(compounds.count).", applied: pitLaps)
        }
        let strictlyAscending = zip(pitLaps, pitLaps.dropFirst()).allSatisfy { $0 < $1 }
        guard strictlyAscending, pitLaps.allSatisfy({ $0 > 0 && $0 < totalLaps }) else {
            return failure("Resulting pitLaps \(pitLaps) must be strictly ascending and each between 1 and \(totalLaps - 1). A shift may have moved a stop past its neighbour or outside the race.", applied: pitLaps)
        }
        guard pitLaps.count <= 4 else {
            return failure("\(pitLaps.count) stops is unrealistic; use at most 4.", applied: pitLaps)
        }
        let allowed: Set<String> = ["SOFT", "MEDIUM", "HARD"]
        if let bad = compounds.first(where: { !allowed.contains($0) }) {
            return failure("Unknown compound '\(bad)'. Use SOFT, MEDIUM or HARD.", applied: pitLaps)
        }

        // MARK: Deterministic stint construction

        let boundaries = [1] + pitLaps.map { $0 + 1 }
        let ends = pitLaps + [totalLaps]
        let hypoStints = zip(boundaries, ends).enumerated().map { i, pair in
            F1PredictorStint(
                meetingKey: 0, sessionKey: 0, stintNumber: i + 1, driverNumber: driver,
                lapStart: pair.0, lapEnd: pair.1, compound: compounds[i], tyreAgeAtStart: 0
            )
        }
        print(hypoStints)

        // MARK: Structural diff vs. actual

        var diff: [String] = []
        if hypoStints.count != actualStints.count {
            diff.append("stint count: \(actualStints.count) → \(hypoStints.count)")
        }
        for i in 0..<min(hypoStints.count, actualStints.count) {
            let h = hypoStints[i], a = actualStints[i]
            if h.lapEnd != a.lapEnd {
                diff.append("stint \(i+1) end lap: \(a.lapEnd.map(String.init) ?? "?") → \(h.lapEnd.map(String.init) ?? "?")")
            }
            if (h.compound ?? "").uppercased() != (a.compound ?? "").uppercased() {
                diff.append("stint \(i+1) compound: \(a.compound ?? "?") → \(h.compound ?? "?")")
            }
        }

        if diff.isEmpty {
            return EvaluatePitStrategyResult(
                success: false,
                errorMessage: "These edits produce the driver's actual strategy unchanged (pitLaps \(baselinePits), compounds \(baselineCompounds)). A shift of 0 or a no-op edit changes nothing. Apply the change the user asked for and call again.",
                totalRaceTimeSeconds: nil, deltaVsActualSeconds: nil,
                stopCountEvaluated: nil, compoundsUsed: nil,
                identicalToActualStrategy: true, structuralDiff: [],
                baselinePitLaps: baselinePits, appliedPitLaps: pitLaps
            )
        }

        // MARK: Evaluate

        let calc = StrategyCalculator.shared
        let models = calc.buildDegradationModels(from: vm.annotatedLaps)
        let hypoTime = calc.totalRaceTime(for: hypoStints, median: median, trackModel: trackModel, models: models)
        let actualTime = calc.totalRaceTime(for: actualStints, median: median, trackModel: trackModel, models: models)

        let result = EvaluatePitStrategyResult(
            success: true,
            errorMessage: nil,
            totalRaceTimeSeconds: hypoTime,
            deltaVsActualSeconds: hypoTime - actualTime,
            stopCountEvaluated: pitLaps.count,
            compoundsUsed: compounds,
            identicalToActualStrategy: false,
            structuralDiff: diff,
            baselinePitLaps: baselinePits,
            appliedPitLaps: pitLaps
        )
        print("RESULT\(result)")
        onResult(hypoStints, result)
        return result
    }

    // MARK: - Edit application

    private static func apply(
        _ edits: [StrategyEdit], pits: [Int], compounds: [String]
    ) throws -> (pits: [Int], compounds: [String]) {
        var pits = pits
        var compounds = compounds

        // Resolves a 1-based stop number; defaults to stop 1 when the driver made exactly one stop.
        func stopIndex(_ stop: Int?, tag: String) throws -> Int {
            guard !pits.isEmpty else {
                throw PlanError(message: "\(tag): the plan has no stops to modify.")
            }
            guard let n = stop else {
                if pits.count == 1 { return 0 }
                throw PlanError(message: "\(tag): `stop` is required because there are \(pits.count) stops.")
            }
            if (1...pits.count).contains(n) { return n - 1 }
            // The model often passes a pit LAP (e.g. 10) where a stop NUMBER (1) belongs.
            if let byLap = pits.firstIndex(of: n) { return byLap }
            if pits.count == 1 { return 0 }
            throw PlanError(message: "\(tag): `stop` is a stop NUMBER (1 = first stop), not a lap. The plan has \(pits.count) stop(s).")
        }

        for (i, edit) in edits.enumerated() {
            let tag = "Edit \(i + 1) (\(edit.kind))"
            switch edit.kind {

            case .shiftStop:
                guard let laps = edit.laps else {
                    throw PlanError(message: "\(tag): `laps` is required.")
                }
                let idx = try stopIndex(edit.stop, tag: tag)
                pits[idx] += laps

            case .addStop:
                guard let lap = edit.atLap, let c = edit.compound else {
                    throw PlanError(message: "\(tag): `atLap` and `compound` are required.")
                }
                guard !pits.contains(lap) else {
                    throw PlanError(message: "\(tag): there is already a stop on lap \(lap).")
                }
                // New stop splits a stint; the stint after the new stop gets the new compound.
                let insertAt = pits.firstIndex(where: { $0 > lap }) ?? pits.count
                pits.insert(lap, at: insertAt)
                compounds.insert(c.uppercased(), at: insertAt + 1)

            case .removeStop:
                let idx = try stopIndex(edit.stop, tag: tag)
                // Skipping a stop merges the two stints; keep the earlier stint's tyre.
                pits.remove(at: idx)
                compounds.remove(at: idx + 1)

            case .setCompound:
                guard let s = edit.stint, let c = edit.compound else {
                    throw PlanError(message: "\(tag): `stint` and `compound` are required.")
                }
                guard (1...compounds.count).contains(s) else {
                    throw PlanError(message: "\(tag): stint \(s) doesn't exist; the plan has \(compounds.count) stint(s).")
                }
                compounds[s - 1] = c.uppercased()
            }
        }
        return (pits, compounds)
    }
}
