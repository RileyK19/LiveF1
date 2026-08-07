//
//  TrackColors.swift
//  LiveF1
//
//  Created by Riley Koo on 7/24/26.
//


import SwiftUI

enum TrackColors {

    /// Ordered so the first color reads well as a "primary" stroke/accent,
    /// and the full array works as gradient stops (top-leading -> bottom-trailing).
    static let map: [String: [Color]] = [
        "abu-dhabi":   [Color(hex: "FF0000"), Color(hex: "00732F"), Color(hex: "FFFFFF"), Color(hex: "000000")], // UAE
        "austin":      [Color(hex: "B22234"), Color(hex: "FFFFFF"), Color(hex: "3C3B6E")], // USA
        "bahrain":     [Color(hex: "CE1126"), Color(hex: "FFFFFF")], // Bahrain
        "baku":        [Color(hex: "00B5E2"), Color(hex: "ED2939"), Color(hex: "00AF66")], // Azerbaijan
        "barcelona":   [Color(hex: "AA151B"), Color(hex: "F1BF00")], // Spain
        "budapest":    [Color(hex: "CD2A3E"), Color(hex: "FFFFFF"), Color(hex: "436F4D")], // Hungary
        "imola":       [Color(hex: "008C45"), Color(hex: "FFFFFF"), Color(hex: "CD212A")], // Italy
        "istanbul":    [Color(hex: "E30A17"), Color(hex: "FFFFFF")], // Turkey
        "jeddah":      [Color(hex: "006C35"), Color(hex: "FFFFFF")], // Saudi Arabia
        "las-vegas":   [Color(hex: "B22234"), Color(hex: "FFFFFF"), Color(hex: "3C3B6E")], // USA
        "lusail":      [Color(hex: "8D1B3D"), Color(hex: "FFFFFF")], // Qatar
        "madrid":      [Color(hex: "AA151B"), Color(hex: "F1BF00")], // Spain
        "marina-bay":  [Color(hex: "ED2939"), Color(hex: "FFFFFF")], // Singapore
        "melbourne":   [Color(hex: "00247D"), Color(hex: "FFFFFF"), Color(hex: "E4002B")], // Australia
        "mexico-city": [Color(hex: "006847"), Color(hex: "FFFFFF"), Color(hex: "CE1126")], // Mexico
        "miami":       [Color(hex: "B22234"), Color(hex: "FFFFFF"), Color(hex: "3C3B6E")], // USA
        "monte-carlo": [Color(hex: "CE1126"), Color(hex: "FFFFFF")], // Monaco
        "montreal":    [Color(hex: "FF0000"), Color(hex: "FFFFFF")], // Canada
        "monza":       [Color(hex: "008C45"), Color(hex: "FFFFFF"), Color(hex: "CD212A")], // Italy
        "são-paulo":   [Color(hex: "009C3B"), Color(hex: "FFDF00"), Color(hex: "002776")], // Brazil
        "sepang": [Color(hex: "010066"), Color(hex: "CC0001"), Color(hex: "FFCC00"), Color(hex: "FFFFFF")], // Malaysia
        "shanghai":    [Color(hex: "DE2910"), Color(hex: "FFDE00")], // China
        "silverstone": [Color(hex: "C8102E"), Color(hex: "FFFFFF"), Color(hex: "012169")], // UK
        "spa":         [Color(hex: "000000"), Color(hex: "FDDA24"), Color(hex: "EF3340")], // Belgium
        "spielberg":   [Color(hex: "ED2939"), Color(hex: "FFFFFF")], // Austria
        "suzuka":      [Color(hex: "BC002D"), Color(hex: "FFFFFF")], // Japan
        "zandvoort":   [Color(hex: "AE1C28"), Color(hex: "FFFFFF"), Color(hex: "21468B")], // Netherlands
    ]

    /// Fallback gradient if a track slug isn't found in the map.
    static let fallback: [Color] = [Color.red, Color.black]

    static func colors(for trackName: String) -> [Color] {
        let key = trackName.lowercased().replacingOccurrences(of: " ", with: "-")
        return map[key] ?? fallback
    }

    static func gradient(for trackName: String) -> LinearGradient {
        LinearGradient(
            colors: colors(for: trackName),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// A softened version (lower opacity) — good for widget backgrounds
    /// so text/foreground content stays legible on top.
    static func softGradient(for trackName: String, opacity: Double = 0.35) -> LinearGradient {
        LinearGradient(
            colors: colors(for: trackName).map { $0.opacity(opacity) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
