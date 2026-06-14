//
//  TyreBadge.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI

// MARK: - Tyre badge

struct TyreBadge: View {
    @AppStorage("isDark") private var isDark = false

    let compound: String
    let age: Int

    var colour: Color {
        switch compound {
        case "SOFT":   return .red
        case "MEDIUM": return .yellow
        case "HARD":   return isDark ? .white : .black
        case "INTER":  return .green
        case "WET":    return .blue
        default:       return .gray
        }
    }

    var letter: String {
        switch compound {
        case "SOFT":   return "S"
        case "MEDIUM": return "M"
        case "HARD":   return "H"
        case "INTER":  return "I"
        case "WET":    return "W"
        default:       return "?"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .stroke(colour, lineWidth: 1.5)
                .frame(width: 16, height: 16)
                .overlay(Text(letter).font(.system(size: 9).bold()).foregroundStyle(colour))
                .padding(2)
            Text("\(age)").font(.system(size: 8)).foregroundStyle(.gray)
        }
    }
}
