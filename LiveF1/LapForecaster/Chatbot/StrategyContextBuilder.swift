//
//  StrategyContext.swift
//  LiveF1
//
//  Created by Riley Koo on 6/15/26.
//


//  StrategyContextBuilder.swift

import Foundation

struct StrategyContext {
    let raceName: String
    let totalLaps: Int
    let selectedDriver: Int
    let selectedDriverStints: [F1PredictorStint]
    let allDriverStrategies: [DriverStrategy]
    let strategyTemplates: [StrategyTemplate]
    let availableCompounds: [String]

    struct DriverStrategy {
        let driverNumber: Int
        let stints: [F1PredictorStint]
        var stopCount: Int { stints.count - 1 }
        var pitLaps: [Int] { stints.dropFirst().compactMap { $0.lapStart } }
    }

    struct StrategyTemplate {
        let stopCount: Int
        let compounds: [String]
        let averagePitLaps: [Int]
        let driverCount: Int
    }

    func systemPrompt() -> String {
        """
        You are an F1 strategy assistant for \(raceName). Your only job is to translate natural language strategy requests into a structured stint array. You never calculate lap times or race results yourself — only output stint data.

        Race info:
        - Total laps: \(totalLaps)
        - Selected driver: #\(selectedDriver)
        - Available compounds: \(availableCompounds.joined(separator: ", "))

        Selected driver's actual strategy:
        \(selectedDriverStints.map { "  Stint \($0.stintNumber): \($0.compound) laps \($0.lapStart)-\($0.lapEnd ?? totalLaps)" }.joined(separator: "\n"))

        All driver strategies this race:
        \(allDriverStrategies.map { d in
            "  #\(d.driverNumber): \(d.stints.map { $0.compound }.joined(separator: " -> ")) | pit laps: \(d.pitLaps.map(String.init).joined(separator: ", "))"
        }.joined(separator: "\n"))

        Strategy templates observed this race:
        \(strategyTemplates.map { t in
            "  \(t.stopCount) stop (\(t.compounds.joined(separator: " -> "))): avg pit laps \(t.averagePitLaps.map(String.init).joined(separator: ", ")) — used by \(t.driverCount) drivers"
        }.joined(separator: "\n"))

        Rules:
        - Always start stint 1 on lap 1
        - Always end the last stint on lap \(totalLaps)
        - Lap ranges must be contiguous with no gaps
        - Only use available compounds
        - Return stints in order
        - Make reasonable assumptions about pit laps based on the templates above
        - If asked to modify the actual strategy (e.g. "pit 3 laps earlier"), adjust the actual pit laps accordingly
        """
    }
}

struct StrategyContextBuilder {

    static func build(
        session: F1PredictorSession,
        laps: [F1Lap],
        stints: [F1PredictorStint],
        selectedDriver: Int
    ) -> StrategyContext {
        let totalLaps = laps.map { $0.lapNumber }.max() ?? 0
        let allDriverNumbers = Array(Set(stints.map { $0.driverNumber })).sorted()

        // Build per driver strategies
        let allDriverStrategies = allDriverNumbers.compactMap { driver -> StrategyContext.DriverStrategy? in
            let driverStints = stints.stints(for: driver)
            guard !driverStints.isEmpty else { return nil }
            return StrategyContext.DriverStrategy(driverNumber: driver, stints: driverStints)
        }

        // Build strategy templates by grouping drivers with same stop count + compound sequence
        let templates = buildTemplates(from: allDriverStrategies)

        // Available compounds this race
        let availableCompounds = Array(Set(stints.map { $0.compound })).sorted()

        let selectedDriverStints = stints.stints(for: selectedDriver)

        return StrategyContext(
            raceName: session.countryName,
            totalLaps: totalLaps,
            selectedDriver: selectedDriver,
            selectedDriverStints: selectedDriverStints,
            allDriverStrategies: allDriverStrategies,
            strategyTemplates: templates,
            availableCompounds: availableCompounds
        )
    }

    private static func buildTemplates(
        from strategies: [StrategyContext.DriverStrategy]
    ) -> [StrategyContext.StrategyTemplate] {
        // Group by stop count
        let byStopCount = Dictionary(grouping: strategies, by: \.stopCount)

        return byStopCount.compactMap { stopCount, drivers -> StrategyContext.StrategyTemplate? in
            guard !drivers.isEmpty else { return nil }

            // Most common compound sequence for this stop count
            let sequences = drivers.map { $0.stints.map { $0.compound }.joined(separator: ",") }
            let mostCommon = sequences.reduce(into: [:]) { $0[$1, default: 0] += 1 }
                .max(by: { $0.value < $1.value })?.key ?? ""
            let compounds = mostCommon.split(separator: ",").map(String.init)

            // Average pit laps across drivers with this stop count
            let allPitLaps = drivers.map { $0.pitLaps }
            let maxStints = allPitLaps.map { $0.count }.max() ?? 0
            let averagePitLaps = (0..<maxStints).map { i -> Int in
                let lapsAtIndex = allPitLaps.compactMap { $0.count > i ? $0[i] : nil }
                return lapsAtIndex.isEmpty ? 0 : lapsAtIndex.reduce(0, +) / lapsAtIndex.count
            }

            return StrategyContext.StrategyTemplate(
                stopCount: stopCount,
                compounds: compounds,
                averagePitLaps: averagePitLaps,
                driverCount: drivers.count
            )
        }
        .sorted { $0.stopCount < $1.stopCount }
    }
}