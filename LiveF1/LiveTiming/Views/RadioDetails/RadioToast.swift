//
//  RadioToast.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI
import AVFoundation

struct RadioToast: View {
    @ObservedObject var store: F1SessionStore
    let msgId: String
    
    var msg: RadioMessage? {
        store.radioMessages.first(where: { $0.id == msgId })
    }
    @AppStorage("isDark") private var isDark = false
    @State private var player: AVPlayer?

    var body: some View {
        guard let msg else { return AnyView(EmptyView()) }
        return AnyView(
            HStack(spacing: 10) {
                Rectangle()
                    .fill(msg.teamColour)
                    .frame(width: 3, height: 32)
                    .cornerRadius(1.5)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("📻 \(msg.driverTla)")
                        .font(.caption.bold())
                        .foregroundStyle(isDark ? .white : .black)
                    if let t = msg.transcription {
                        Text(t)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("Transcribing...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .shadow(radius: 4)
            .padding(.horizontal, 12)
        )
    }
}
