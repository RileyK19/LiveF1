//
//  RadioView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//


import SwiftUI
import AVFoundation

struct RadioView: View {
    @ObservedObject var store: F1SessionStore
    @AppStorage("isDark") private var isDark = false
    @State private var player: AVPlayer?
    @State private var playingId: String?

    var body: some View {
        List(store.radioMessages) { msg in
            HStack(spacing: 12) {
                Rectangle()
                    .fill(msg.teamColour)
                    .frame(width: 3)
                    .cornerRadius(1.5)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(msg.driverTla)
                        .font(.caption.bold())
                        .foregroundStyle(isDark ? .white : .black)
                    Text(formatTime(msg.utc))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    play(msg)
                } label: {
                    Image(systemName: playingId == msg.id ? "stop.fill" : "play.fill")
                        .foregroundStyle(msg.teamColour)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Team Radio")
        .background(isDark ? Color.black : Color.white)
    }

    private func play(_ msg: RadioMessage) {
        if playingId == msg.id {
            player?.pause()
            player = nil
            playingId = nil
        } else {
            guard let url = msg.audioURL else { return }
            player = AVPlayer(url: url)
            player?.play()
            playingId = msg.id
        }
    }

    private func formatTime(_ utc: String) -> String {
        // "2025-03-16T03:16:04.01Z" → "03:16:04"
        let parts = utc.components(separatedBy: "T")
        guard parts.count == 2 else { return utc }
        return String(parts[1].prefix(8))
    }
}
