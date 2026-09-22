//
//  F1SessionAttributes.swift
//  Redline
//
//  Created by Riley Koo on 9/19/26.
//


import ActivityKit

struct F1SessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var leaderTLA: String
        var leaderGap: String
        var p2TLA: String
        var p2Gap: String
        var p3TLA: String
        var p3Gap: String
        var trackStatus: String
        var lapCount: String
    }

    var sessionName: String  // "Race", "Qualifying", etc — set once at start
}