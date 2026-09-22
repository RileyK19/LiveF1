//
//  AppAssistantView.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//

import SwiftUI

struct AppAssistantView: View {
    @EnvironmentObject var currentSessionStore: CurrentSessionStore
    @EnvironmentObject var championshipStore: ChampionshipDataStore
    @EnvironmentObject var fiaStore: FIADocumentStore
    @StateObject private var translator = AppAssistantTranslator()
    @State private var prompt: String = ""
    @State private var messages: [AssistantMessage] = []
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
//            Button {
//                print("messages")
//                for message in messages {
//                    print(message.content)
//                }
//            } label: {
//                Text("Debug :D")
//            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty { suggestionsView }
                        ForEach(messages) { message in
                            AssistantChatBubbleView(message: message, viewModel: currentSessionStore.raceViewModel)                                .id(message.id)
                        }
                        if translator.isThinking {
                            thinkingIndicator.id("thinking")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
//                    print(messages.last?.content)
                    withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                }
            }

            Divider()

            HStack(spacing: 12) {
                TextField("Ask about strategy or championship...", text: $prompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($inputFocused)

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(prompt.isEmpty ? .secondary : .red)
                }
                .disabled(prompt.isEmpty || translator.isThinking)
            }
            .padding(12)
            .background(.bar)
        }
        .navigationTitle("Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: translator.selectionCoordinator.currentOptions) { _, options in
            if let options {
                messages.append(AssistantMessage(
                    role: .assistant,
                    card: .sessionPicker(options: options, coordinator: translator.selectionCoordinator)
                ))
            }
        }
        .alert("Error", isPresented: Binding(
            get: { translator.error != nil },
            set: { if !$0 { translator.error = nil } }
        )) {
            Button("OK") { translator.error = nil }
        } message: {
            Text(translator.error ?? "")
        }
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(0.4)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2),
                        value: translator.isThinking
                    )
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var suggestions: [String] = [
        "When is the next upcoming race weekend?",
        "Who's first in the driver's standings right now?",
        "What if Verstappen pitted 5 laps earlier in Melbourne?",
        "Who had the fastest race pace in Suzuka?",
        "What was pole in China?"
    ]
    
    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try asking...")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    prompt = suggestion
                    send()
                } label: {
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(12)
                        .background(.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }


    private func send() {
        guard !prompt.isEmpty else { return }

        let userMessage = AssistantMessage(role: .user, text: prompt)
        messages.append(userMessage)
        let currentPrompt = prompt
        prompt = ""
        inputFocused = false

        Task { @MainActor in
            if let text = await translator.respond(
                to: currentPrompt,
                sessionStore: currentSessionStore,
                championshipStore: championshipStore,
                fiaStore: fiaStore
            ) {
                messages.append(AssistantMessage(role: .assistant, text: text))
                for card in translator.pendingCards {
                    messages.append(AssistantMessage(role: .assistant, card: card))
                }
            } else if let error = translator.error {
                messages.append(AssistantMessage(role: .assistant, text: "Sorry, I couldn't process that: \(error)"))
            }
        }
    }
}
