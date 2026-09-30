//
//  RaceResultsExportLayout.swift
//  Redline
//
//  Created by Riley Koo on 9/28/26.
//

import SwiftUI

struct RaceResultsExportLayout: View {
    let raceName: String
    let results: [ChampionshipRaceResult]
    let generatedDate: Date = .now

    private let gridRowHeight: CGFloat = 44
    private let gridSpacing: CGFloat = 6

    private var sorted: [ChampionshipRaceResult] {
        results.sorted { (Int($0.position) ?? 99) < (Int($1.position) ?? 99) }
    }

    private var podium: [ChampionshipRaceResult] { Array(sorted.prefix(3)) }
    private var rest: [ChampionshipRaceResult] { Array(sorted.dropFirst(3)) }

    // Real starting-grid style: odd positions left, even positions right,
    // with the left column sitting half a row behind the right one.
    private var leftColumn: [ChampionshipRaceResult] {
        rest.filter { (Int($0.position) ?? 0) % 2 == 1 }
    }
    private var rightColumn: [ChampionshipRaceResult] {
        rest.filter { (Int($0.position) ?? 0) % 2 == 0 }
    }

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
            Text("\(raceName) Classification")
                .font(.system(size: 28, weight: .bold, design: .serif))
        }
    }


    // MARK: - Podium (P2 | P1 | P3)

    private var podiumView: some View {
        let byPos = Dictionary(uniqueKeysWithValues: podium.compactMap { r in
            Int(r.position).map { ($0, r) }
        })

        return HStack(alignment: .bottom, spacing: 12) {
            if let p2 = byPos[2] { PodiumCard(result: p2, height: 110) }
            if let p1 = byPos[1] { PodiumCard(result: p1, height: 135) }
            if let p3 = byPos[3] { PodiumCard(result: p3, height: 95) }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Starting grid

    private var gridView: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: gridSpacing) {
                ForEach(rightColumn) { GridSlot(result: $0, height: gridRowHeight) }
            }
            VStack(spacing: gridSpacing) {
                ForEach(leftColumn) { GridSlot(result: $0, height: gridRowHeight) }
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
    let result: ChampionshipRaceResult
    let height: CGFloat

    private var teamColor: Color { Color(hex: result.teamColor) }
    private var isWinner: Bool { result.position == "1" }

    var body: some View {
        VStack(spacing: 3) {
            Text("P\(result.position)")
                .font(.system(size: isWinner ? 32 : 26, weight: .heavy, design: .rounded))
                .foregroundStyle(teamColor)

            Text(result.driverName)
                .font(isWinner ? .headline.weight(.bold) : .subheadline.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text(result.constructorName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text("\(result.points) pts")
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
    let result: ChampionshipRaceResult
    let height: CGFloat

    private var teamColor: Color { Color(hex: result.teamColor) }
    private var didFinish: Bool { result.status == "Finished" || result.status.contains("Lap") }

    var body: some View {
        HStack(spacing: 10) {
            Text(result.position)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 30)

            RoundedRectangle(cornerRadius: 2)
                .fill(teamColor)
                .opacity(didFinish ? 1 : 0.4)
                .frame(width: 3, height: height - 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.driverName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(didFinish ? result.constructorName : result.status)
                    .font(.caption)
                    .foregroundStyle(didFinish ? Color.secondary : Color.red)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if result.points != "0" {
                Text("+\(result.points)")
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
