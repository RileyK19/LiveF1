//
//  NameMatcher.swift
//  Redline
//
//  Created by Riley Koo on 9/9/26.
//


import Foundation

enum NameMatcher {
    /// Best-effort match of free text (e.g. "Max", "Verstapen", "Norris") against a
    /// small list of known driver names. Always returns the closest candidate if the
    /// list is non-empty — this is a starting guess, not a validation gate, since the
    /// UI's "compare against" picker lets the user correct it for free either way.
    static func bestGuess(for query: String, in drivers: [(number: Int, fullName: String)]) -> Int? {
        let q = normalize(query)
        guard !q.isEmpty, !drivers.isEmpty else { return nil }

        if let hit = drivers.first(where: { normalize($0.fullName).contains(q) || q.contains(normalize($0.fullName)) }) {
            return hit.number
        }

        let scored: [(number: Int, score: Double)] = drivers.map { driver in
            let full = normalize(driver.fullName)
            let last = normalize(driver.fullName.split(separator: " ").last.map(String.init) ?? driver.fullName)
            return (driver.number, max(similarity(q, full), similarity(q, last)))
        }.sorted { $0.score > $1.score }

        return scored.first?.number
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func similarity(_ a: String, _ b: String) -> Double {
        let dist = levenshtein(a, b)
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else { return 1 }
        return 1 - Double(dist) / Double(maxLen)
    }

    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var dp = Array(0...b.count)
        for i in 1...a.count {
            var prev = dp[0]
            dp[0] = i
            for j in 1...b.count {
                let temp = dp[j]
                dp[j] = a[i-1] == b[j-1] ? prev : 1 + min(prev, dp[j-1], dp[j])
                prev = temp
            }
        }
        return dp[b.count]
    }
}
