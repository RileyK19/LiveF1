//
//  EventLogView.swift
//  LiveF1
//
//  Created by Riley Koo on 7/29/26.
//

import SwiftUI
import AVFoundation

struct EventLogView: View {
    @ObservedObject var store: F1SessionStore

    var body: some View {
        List(store.combinedLog) { entry in
            switch entry {
            case .radio(let msg):
                RadioLogRow(msg: msg)
            case .raceControl(let msg):
                RaceControlLogRow(msg: msg)
            }
        }
        .listStyle(.plain)
    }
}

struct RaceControlLogRow: View {
    let msg: RaceControlMessage
    var flagColor: Color {
        switch msg.flag {
        case "YELLOW", "DOUBLE YELLOW": return .yellow
        case "RED": return .red
        case "GREEN", "CLEAR": return .green
        case "BLUE": return .blue
        case "CHEQUERED": return .primary
        default: return .secondary
        }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(flagColor).frame(width: 8, height: 8).padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(msg.message).font(.subheadline)
                if let lap = msg.lap {
                    Text("Lap \(lap)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct RadioLogRow: View {
    let msg: RadioMessage
    @State private var player: AVPlayer?

    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(msg.teamColour).frame(width: 3).cornerRadius(1.5)
            VStack(alignment: .leading, spacing: 2) {
                Text("📻 \(msg.driverTla)").font(.caption.bold())
                Text(msg.transcription ?? "Transcribing...")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Button {
                if let url = msg.audioURL {
                    player = AVPlayer(url: url)
                    player?.play()
                }
            } label: {
                Image(systemName: "play.fill")
                    .foregroundStyle(msg.teamColour)
            }
            .buttonStyle(.plain)
        }
    }
}
