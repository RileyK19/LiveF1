//
//  ManualStrategyView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/15/26.
//


//  ManualStrategyView.swift

import SwiftUI

struct ManualStrategyView: View {
    @ObservedObject var viewModel: RaceViewModel
    @State private var stints: [EditableStint] = []
    @State private var showResult = false

    var totalLaps: Int {
        viewModel.laps.map { $0.lapNumber }.max() ?? 78
    }
    
    private var driverComparisonPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Compare Against")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Self option
                    Button {
                        viewModel.comparisonDriverNumber = nil
                    } label: {
                        Text("#\(viewModel.selectedDriverNumber ?? 0) (self)")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(viewModel.comparisonDriverNumber == nil ? Color.red : Color.secondary.opacity(0.15))
                            .foregroundStyle(viewModel.comparisonDriverNumber == nil ? .white : .primary)
                            .clipShape(Capsule())
                    }

                    ForEach(viewModel.drivers.filter { $0 != viewModel.selectedDriverNumber }, id: \.self) { driver in
                        Button {
                            viewModel.comparisonDriverNumber = driver
                        } label: {
                            Text("#\(driver)")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(viewModel.comparisonDriverNumber == driver ? Color.red : Color.secondary.opacity(0.15))
                                .foregroundStyle(viewModel.comparisonDriverNumber == driver ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                driverComparisonPicker

                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    // Stints editor
                    ForEach($stints) { $stint in
                        StintEditorRow(
                            stint: $stint,
                            totalLaps: totalLaps,
                            onDelete: {
                                stints.removeAll { $0.id == stint.id }
                                recalculateLapRanges()
                            }
                        )
                    }

                    // Add stint button
                    Button {
                        addStint()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Stint")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Validation warnings
                    if let warning = incompleteDataWarning {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(warning)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let warning = validationWarning {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(warning)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(.yellow.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Calculate button
                    Button {
                        applyStrategy()
                    } label: {
                        Text("Calculate Strategy")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(isValid ? Color.red : Color.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!isValid)

                    // Result card
                    if showResult, let hypothetical = viewModel.hypotheticalStints {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Result")
                                .font(.headline)
                            StrategyResultCard(
                                actual: viewModel.stintsForSelectedDriver,
                                hypothetical: hypothetical,
                                timeDelta: viewModel.calculateTimeDeltaVsDriver(hypothetical: hypothetical),
                                viewModel: viewModel
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            if stints.isEmpty { loadActualStrategy() }
        }
    }

    // MARK: - Load actual strategy as starting point

    private func loadActualStrategy() {
        stints = viewModel.stintsForSelectedDriver.map { stint in
            EditableStint(
                lapStart: stint.lapStart,
                lapEnd: stint.lapEnd ?? totalLaps,
                compound: TyreCompound(rawValue: stint.compound) ?? .medium
            )
        }
        if stints.isEmpty { addStint() }
    }

    // MARK: - Add stint

    private func addStint() {
        let lastEnd = stints.last?.lapEnd ?? 0
        let newStart = lastEnd + 1
        let newEnd = min(newStart + 20, totalLaps)
        stints.append(EditableStint(lapStart: newStart, lapEnd: newEnd, compound: .medium))
        recalculateLapRanges()
    }

    // MARK: - Recalculate so stints are contiguous

    private func recalculateLapRanges() {
        guard !stints.isEmpty else { return }
        stints[0].lapStart = 1
        for i in 1..<stints.count {
            stints[i].lapStart = stints[i - 1].lapEnd + 1
        }
        stints[stints.count - 1].lapEnd = totalLaps
    }

    // MARK: - Validation

    private var isValid: Bool {
        guard !stints.isEmpty else { return false }
        guard stints[0].lapStart == 1 else { return false }
        guard stints.last?.lapEnd == totalLaps else { return false }
        for i in 0..<stints.count - 1 {
            if stints[i].lapEnd >= stints[i + 1].lapStart { return false }
            if stints[i].lapEnd < stints[i].lapStart { return false }
        }
        return true
    }
    
    private var incompleteDataWarning: String? {
        let baseStints = viewModel.comparisonDriverNumber != nil
            ? viewModel.stintsForComparisonDriver
            : viewModel.stintsForSelectedDriver

        let lastLap = baseStints.compactMap(\.lapEnd).max() ?? 0
        guard lastLap > 0, lastLap < totalLaps - 2 else { return nil }

        let driver = viewModel.comparisonDriverNumber ?? viewModel.selectedDriverNumber ?? 0
        return "Data for #\(driver) only goes to lap \(lastLap)/\(totalLaps) — comparison may be inaccurate"
    }

    private var validationWarning: String? {
        if stints.isEmpty { return "Add at least one stint" }
        if stints[0].lapStart != 1 { return "First stint must start on lap 1" }
        if stints.last?.lapEnd != totalLaps { return "Last stint must end on lap \(totalLaps)" }
        for i in 0..<stints.count - 1 {
            if stints[i].lapEnd >= stints[i + 1].lapStart {
                return "Stint \(i + 1) and \(i + 2) overlap"
            }
        }
        return nil
    }

    // MARK: - Apply

    private func applyStrategy() {
        let converted = stints.enumerated().map { index, editable in
            F1PredictorStint(
                meetingKey: viewModel.session.meetingKey,
                sessionKey: viewModel.session.sessionKey,
                stintNumber: index + 1,
                driverNumber: viewModel.selectedDriverNumber ?? 0,
                lapStart: editable.lapStart,
                lapEnd: editable.lapEnd,
                compound: editable.compound.rawValue,
                tyreAgeAtStart: 0
            )
        }
        viewModel.hypotheticalStints = converted
        showResult = true
    }
}

// MARK: - Editable stint model

struct EditableStint: Identifiable {
    let id = UUID()
    var lapStart: Int
    var lapEnd: Int
    var compound: TyreCompound
}

// MARK: - Stint editor row

struct StintEditorRow: View {
    @Binding var stint: EditableStint
    let totalLaps: Int
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Compound picker
                Menu {
                    ForEach([TyreCompound.soft, .medium, .hard, .intermediate, .wet], id: \.rawValue) { compound in
                        Button {
                            stint.compound = compound
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: compound.color))
                                    .frame(width: 10, height: 10)
                                Text(compound.rawValue.capitalized)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: stint.compound.color))
                            .frame(width: 12, height: 12)
                        Text(stint.compound.rawValue.capitalized)
                            .font(.subheadline.bold())
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Lap range sliders
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Start: Lap \(stint.lapStart)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("End: Lap \(stint.lapEnd)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Start lap stepper
                HStack {
                    Text("Pit in")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Stepper("Lap \(stint.lapStart)", value: $stint.lapStart, in: 1...max(1, stint.lapEnd - 1))
                        .labelsHidden()
                    Text("Lap \(stint.lapStart)")
                        .font(.caption)
                        .monospacedDigit()
                    Spacer()
                }

                // End lap stepper
                HStack {
                    Text("Pit out")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Stepper("Lap \(stint.lapEnd)", value: $stint.lapEnd, in: max(stint.lapStart + 1, 2)...totalLaps)
                        .labelsHidden()
                    Text("Lap \(stint.lapEnd)")
                        .font(.caption)
                        .monospacedDigit()
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
