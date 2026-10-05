//
//  PitViews.swift
//  LiveF1
//

import SwiftUI

/// Placeholder thresholds. Tune against the validation race.
enum PitThresholds {
    static let noMoreStops = 0.25      // P(will stop) below this: "no more stops"
    static let possible = 0.35         // P(within 5) bands
    static let likely = 0.60
    static let soon = 0.85
    static let showWindowIfMedianAtMost = 10.0
}

struct PitChip: View {
    let prediction: PitPrediction?

    var body: some View {
        if let p = prediction {
            content(p)
        } else {
            Text("—").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func content(_ p: PitPrediction) -> some View {
        if p.pWillStop < PitThresholds.noMoreStops {
            chip("No more stops", .gray)
        } else {
            HStack(spacing: 4) {
                if let band = band(p.pWithin5) { chip(band.text, band.colour) }
                if p.lapsMedian <= PitThresholds.showWindowIfMedianAtMost {
                    Text(windowText(p)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func band(_ p: Double) -> (text: String, colour: Color)? {
        if p >= PitThresholds.soon { return ("Soon", .red) }
        if p >= PitThresholds.likely { return ("Likely", .orange) }
        if p >= PitThresholds.possible { return ("Possible", .yellow) }
        return nil
    }

    /// Absolute laps: window low–high, median in brackets.
    private func windowText(_ p: PitPrediction) -> String {
        let lo = p.lap + max(1, Int(p.lapsLow.rounded()))
        let hi = p.lap + max(1, Int(p.lapsHigh.rounded()))
        let med = p.lap + max(1, Int(p.lapsMedian.rounded()))
        return lo == hi ? "L\(med)" : "L\(lo)–\(hi) (\(med))"
    }

    private func chip(_ text: String, _ colour: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(colour.opacity(0.25))
            .foregroundStyle(colour)
            .clipShape(Capsule())
    }
}