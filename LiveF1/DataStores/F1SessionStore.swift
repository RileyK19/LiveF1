//
//  F1SessionStore.swift
//  LiveF1
//
//  Created by Riley Koo on 6/4/26.
//


import Foundation
import SwiftUI
import Combine
import Speech

@MainActor
class F1SessionStore: ObservableObject {
    @Published var rawTopics: [String: Any] = [:]   // raw merged state per topic, for debug view
    @Published var messages: [(topic: String, payload: [String: Any])] = []  // last N messages
    @Published var connectionState: DataSourceState = .disconnected
    @Published var carTelemetry: [String: CarTelemetry] = [:]
    @Published var updateCount: Int = 0
    @Published var radioMessages: [RadioMessage] = []
    private var pendingRadio: [String: Any]?
    
    private let maxMessages = 200
    
    private var transcriptionQueue: [RadioMessage] = []
    private var isTranscribing = false
    
    var dataSource: (any F1DataSource)? {
        didSet {
            dataSource?.onMessage = { [weak self] topic, payload in
                Task { @MainActor in
                    self?.handle(topic: topic, payload: payload)
                }
            }
            dataSource?.onStateChange = { [weak self] state in
                Task { @MainActor in
                    self?.connectionState = state
                }
            }
        }
    }
    
    @Published var drivers: [Driver] = []
    
    private func handle(topic: String, payload: [String: Any]) {
        //        print("📨 \(topic)")
        //        if topic == "TimingData" {
        //            print("🏁 TimingData delta: \(String(describing: payload).prefix(200))")
        //        }
        if topic == "TeamRadio" {
            print("📻 TeamRadio payload: \(payload)")
        }
        
        // Deep-merge the delta into our state for this topic
        if var existing = rawTopics[topic] as? [String: Any] {
            deepMerge(into: &existing, from: payload)
            rawTopics[topic] = existing
        } else {
            rawTopics[topic] = payload
        }
        
        // Keep a log of recent raw messages for the debug view
        messages.append((topic, payload))
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
        drivers = F1TimingParser.parse(store: self)
        
        if topic == "CarData.z", let entries = payload["Entries"] as? [[String: Any]] {
            if let last = entries.last, let cars = last["Cars"] as? [String: Any] {
                for (number, carRaw) in cars {
                    guard let car = carRaw as? [String: Any],
                          let channels = car["Channels"] as? [String: Any]
                    else { continue }
                    carTelemetry[number] = CarTelemetry(
                        rpm:      channels["0"] as? Int ?? 0,
                        speed:    channels["2"] as? Int ?? 0,
                        gear:     channels["3"] as? Int ?? 0,
                        throttle: channels["4"] as? Int ?? 0,
                        brake:    (channels["5"] as? Int ?? 0) == 1,
                        drs:      (channels["45"] as? Int ?? 0) > 0
                    )
                }
            }
        }
        if topic == "TeamRadio" {
            if (rawTopics["SessionInfo"] as? [String: Any])?["Path"] as? String != nil {
                processRadio(payload)
            } else {
                pendingRadio = payload
            }
        }
        
        if topic == "SessionInfo", let pending = pendingRadio {
            pendingRadio = nil
            processRadio(pending)
        }
        updateCount += 1
    }
    
    private func processRadio(_ payload: [String: Any]) {
        print("📻 processRadio called, sessionPath: \((rawTopics["SessionInfo"] as? [String: Any])?["Path"] as? String ?? "nil")")
        var captures: [[String: Any]] = []
        if let arr = payload["Captures"] as? [[String: Any]] {
            captures = arr
        } else if let dict = payload["Captures"] as? [String: Any] {
            captures = dict.values.compactMap { $0 as? [String: Any] }
        }
        guard !captures.isEmpty else { return }
        let driverList = rawTopics["DriverList"] as? [String: Any] ?? [:]
        let sessionPath = (rawTopics["SessionInfo"] as? [String: Any])?["Path"] as? String ?? ""
        for capture in captures {
            guard let path = capture["Path"] as? String,
                  let utc = capture["Utc"] as? String,
                  let number = capture["RacingNumber"] as? String
            else { continue }
            let driver = driverList[number] as? [String: Any] ?? [:]
            let tla = driver["Tla"] as? String ?? number
            let hex = driver["TeamColour"] as? String ?? "FFFFFF"
            let url = URL(string: "https://livetiming.formula1.com/static/\(sessionPath)\(path)")
            let msg = RadioMessage(id: utc, driverNumber: number, driverTla: tla, teamColour: Color(hex: hex), utc: utc, audioURL: url)
            print("📻 inserting radio msg: \(tla) \(utc)")
            if !radioMessages.contains(where: { $0.id == utc }) {
                radioMessages.insert(msg, at: 0)
                print("📻 radioMessages count now: \(radioMessages.count)")
                transcribe(msg)
            }
        }
    }
    
    // Deep merge: for dict values, recurse. For everything else, overwrite.
    // This is how F1's delta stream works — patches come in and we fold them into state.
    private func deepMerge(into target: inout [String: Any], from source: [String: Any]) {
        for (key, value) in source {
            // If source is a dict with integer string keys (like "0", "1", "2")
            // and target is an array, merge by index
            if let sourceDict = value as? [String: Any],
               let targetArr = target[key] as? [[String: Any]],
               sourceDict.keys.allSatisfy({ Int($0) != nil }) {
                var newArr = targetArr
                for (indexStr, update) in sourceDict {
                    if let i = Int(indexStr), i < newArr.count,
                       let updateDict = update as? [String: Any] {
                        var element = newArr[i]
                        deepMerge(into: &element, from: updateDict)
                        newArr[i] = element
                    }
                }
                target[key] = newArr
            } else if value is [Any] {
                target[key] = value
            } else if var targetDict = target[key] as? [String: Any],
                      let sourceDict = value as? [String: Any] {
                deepMerge(into: &targetDict, from: sourceDict)
                target[key] = targetDict
            } else {
                target[key] = value
            }
        }
    }
    
    func clear() {
        rawTopics = [:]
        messages = []
    }
    
    func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { _ in }
    }
    
    private func transcribe(_ msg: RadioMessage) {
        transcriptionQueue.append(msg)
        if !isTranscribing { processTranscriptionQueue() }
    }
    
    private func processTranscriptionQueue() {
        guard !transcriptionQueue.isEmpty else { isTranscribing = false; return }
        isTranscribing = true
        let msg = transcriptionQueue.removeFirst()
        transcribeWithRetry(msg, retries: 3)
    }

    private func transcribeWithRetry(_ msg: RadioMessage, retries: Int) {
        guard let url = msg.audioURL else {
            processTranscriptionQueue()
            return
        }
        
        Task {
            guard let (localURL, _) = try? await URLSession.shared.download(from: url) else {
                await MainActor.run { processTranscriptionQueue() }
                return
            }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
            try? FileManager.default.moveItem(at: localURL, to: tempURL)
            
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB")),
                  recognizer.isAvailable else {
                await MainActor.run { processTranscriptionQueue() }
                return
            }
            
            let request = SFSpeechURLRecognitionRequest(url: tempURL)
            request.shouldReportPartialResults = false
            
            let result: String? = await withCheckedContinuation { continuation in
                var resumed = false
                recognizer.recognitionTask(with: request) { result, error in
                    guard !resumed else { return }
                    if let result, result.isFinal {
                        resumed = true
                        continuation.resume(returning: result.bestTranscription.formattedString)
                    } else if let error {
                        resumed = true
                        continuation.resume(returning: nil)
                        if retries > 0 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                self.transcribeWithRetry(msg, retries: retries - 1)
                            }
                        }
                    }
                }
            }
            if let text = result {
                print("✅ transcription: \(text)")
            } else {
                print("❌ transcription returned nil")
            }
            
            try? FileManager.default.removeItem(at: tempURL)
            
            await MainActor.run {
                if let text = result, let i = self.radioMessages.firstIndex(where: { $0.id == msg.id }) {
                    self.radioMessages[i].transcription = text
                }
                if result != nil || retries == 0 {
                    self.processTranscriptionQueue()
                }
            }
        }
    }
}
