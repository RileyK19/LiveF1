//
//  RaceResultsExportLayout.swift
//  Redline
//
//  Created by Riley Koo on 9/28/26.
//

import SwiftUI

struct ClassificationExportLayout: View {
    let title: String
    let entries: [ExportEntry]
    let generatedDate: Date = .now

    private let gridRowHeight: CGFloat = 44
    private let gridSpacing: CGFloat = 6

    private var sorted: [ExportEntry] { entries.sorted { $0.position < $1.position } }
    private var podium: [ExportEntry] { Array(sorted.prefix(3)) }
    private var rest: [ExportEntry] { Array(sorted.dropFirst(3)) }

    private var leftColumn: [ExportEntry]  { rest.filter { $0.position % 2 == 1 } }
    private var rightColumn: [ExportEntry] { rest.filter { $0.position % 2 == 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            podiumView
            gridView
            footer
        }
        .padding(20)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title) Classification")
                .font(.system(size: 28, weight: .bold, design: .serif))
        }
    }
    
    private var podiumView: some View {
        let byPos = Dictionary(podium.map { ($0.position, $0) }, uniquingKeysWith: { a, _ in a })
        return HStack(alignment: .bottom, spacing: 12) {
            if let p2 = byPos[2] { PodiumCard(entry: p2, height: 110) }
            if let p1 = byPos[1] { PodiumCard(entry: p1, height: 135) }
            if let p3 = byPos[3] { PodiumCard(entry: p3, height: 95) }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Starting grid

    private var gridView: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: gridSpacing) {
                ForEach(rightColumn) { GridSlot(entry: $0, height: gridRowHeight) }
            }
            VStack(spacing: gridSpacing) {
                ForEach(leftColumn) { GridSlot(entry: $0, height: gridRowHeight) }
            }
            .padding(.top, (gridRowHeight + gridSpacing) / 2)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Generated \(generatedDate.formatted(date: .abbreviated, time: .shortened))")
            Spacer()
            Text("Redline F1")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Podium card

private struct PodiumCard: View {
    let entry: ExportEntry
    let height: CGFloat
    private var teamColor: Color { entry.teamColor }
    private var isWinner: Bool { entry.position == 1 }

    var body: some View {
        VStack(spacing: 3) {
            Text("P\(entry.position)")
                .font(.system(size: isWinner ? 32 : 24, weight: .heavy, design: .rounded))
                .foregroundStyle(entry.teamColor)
            Text(entry.driverName)
                .font(isWinner ? .headline.weight(.bold) : .subheadline.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(entry.constructorName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(entry.podiumDetail)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(teamColor.opacity(0.12))
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14)
                .fill(teamColor)
                .frame(height: 5)
        }
    }
}

// MARK: - Grid slot

private struct GridSlot: View {
    let entry: ExportEntry
    let height: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Text("\(entry.position)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 30)

            RoundedRectangle(cornerRadius: 2)
                .fill(entry.teamColor)
                .opacity(entry.issue == nil ? 1 : 0.4)
                .frame(width: 3, height: height - 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.driverName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(entry.issue ?? entry.constructorName)
                    .font(.caption)
                    .foregroundStyle(entry.issue == nil ? Color.secondary : Color.red)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if let detail = entry.gridDetail {
                Text(detail)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct ExportEntry: Identifiable {
    let id: String
    let position: Int
    let driverName: String
    let constructorName: String
    let teamColor: Color
    let podiumDetail: String   // "25 pts" / "1:29.123"
    let gridDetail: String?    // "+8" / "1:30.456" (nil = show nothing)
    let issue: String?         // DNF reason; nil = normal
}

extension ChampionshipRaceResult {
    var exportEntry: ExportEntry {
        let didFinish = status == "Finished" || status.contains("Lap")
        return ExportEntry(
            id: id,
            position: Int(position) ?? 99,
            driverName: driverName,
            constructorName: constructorName,
            teamColor: Color(hex: teamColor),
            podiumDetail: "\(points) pts",
            gridDetail: points != "0" ? "+\(points)" : nil,
            issue: didFinish ? nil : status
        )
    }
}

extension ChampionshipQualifyingResult {
    /// Best available time: Q3 if they made it, else Q2, else Q1
    var bestTime: String? { q3 ?? q2 ?? q1 }

    var exportEntry: ExportEntry {
        ExportEntry(
            id: id,
            position: Int(position) ?? 99,
            driverName: driverName,
            constructorName: constructorName,
            teamColor: Color(hex: teamColor),
            podiumDetail: bestTime ?? "No time",
            gridDetail: bestTime,
            issue: nil
        )
    }
}
