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
import WhisperKit

@MainActor
class F1SessionStore: ObservableObject, Hashable {
    public var id: UUID = UUID()
    @Published var rawTopics: [String: Any] = [:]   // raw merged state per topic, for debug view
    @Published var messages: [(topic: String, payload: [String: Any])] = []  // last N messages
    @Published var connectionState: DataSourceState = .disconnected
    @Published var carTelemetry: [String: CarTelemetry] = [:]
    @Published var updateCount: Int = 0
    @Published var radioMessages: [RadioMessage] = []
    @Published var raceControlMessages: [RaceControlMessage] = []
    @Published var carPositions: [String: CarPosition] = [:]
    @Published var toastQueue: [ToastKind] = []
    @Published var currentToast: ToastKind?
    
    @Published private(set) var isDelayRampingUp: Bool = false
    @Published private(set) var delayRampRemaining: TimeInterval = 0

    private var toastTimer: Task<Void, Never>?
    
    private var pendingRadio: [String: Any]?
    
    private let maxMessages = 200
    
    private var transcriptionQueue: [RadioMessage] = []
    private var isTranscribing = false
    
    var delaySeconds: TimeInterval = 0
    private var buffer: [(releaseAt: Date, topic: String, payload: [String: Any])] = []
    private var flushTask: Task<Void, Never>?
    
    private var whisperPipe: WhisperKit?
    
    static func == (lhs: F1SessionStore, rhs: F1SessionStore) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var dataSource: (any F1DataSource)? {
        didSet {
            dataSource?.onMessage = { [weak self] topic, payload in
                Task { @MainActor in
                    self?.enqueue(topic: topic, payload: payload)
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
    
    enum LogEntry: Identifiable {
        case radio(RadioMessage)
        case raceControl(RaceControlMessage)

        var id: String {
            switch self {
            case .radio(let r): return "radio-\(r.id)"
            case .raceControl(let rc): return "rc-\(rc.id)"
            }
        }
        var utc: String {
            switch self {
            case .radio(let r): return r.utc
            case .raceControl(let rc): return rc.utc
            }
        }
    }

    var combinedLog: [LogEntry] {
        (radioMessages.map(LogEntry.radio) + raceControlMessages.map(LogEntry.raceControl))
            .sorted { $0.utc > $1.utc }
    }
    
    enum ToastKind: Identifiable {
        case radio(String)         // RadioMessage.id
        case raceControl(String)   // RaceControlMessage.id

        var id: String {
            switch self {
            case .radio(let id): return "radio-\(id)"
            case .raceControl(let id): return "rc-\(id)"
            }
        }
    }

    
    init() {
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000) // 5x/sec
                self?.flushDue()
            }
        }
    }

    deinit {
        flushTask?.cancel()
    }
    
    private func handle(topic: String, payload: [String: Any]) {
                print("📨 \(topic)")
//                if topic == "TimingData" {
//                    print("🏁 TimingData delta: \(String(describing: payload).prefix(200))")
//                    print("🏁 TimingData delta: \(String(describing: payload))")
//                }
                if topic == "TimingStats" {
                    print("🏁 TimingStats delta: \(String(describing: payload))")
                }
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
                        brake:    (channels["5"] as? Int ?? 0) == 100,
                        drs:      (channels["45"] as? Int ?? 0) > 0
                    )
                }
            }
        }
        
        if topic == "Position.z", let entries = payload["Position"] as? [[String: Any]] {
            if let last = entries.last, let cars = last["Entries"] as? [String: Any] {
                for (number, carRaw) in cars {
                    guard let car = carRaw as? [String: Any] else { continue }
                    carPositions[number] = CarPosition(
                        x: car["X"] as? Double ?? 0,
                        y: car["Y"] as? Double ?? 0,
                        z: car["Z"] as? Double ?? 0,
                        status: car["Status"] as? String ?? "Unknown"
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
        if topic == "RaceControlMessages" {
            processRaceControl(payload)
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
                enqueueToast(.radio(msg.id))
                transcribe(msg)
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

    private func loadWhisperIfNeeded() async {
        guard whisperPipe == nil else { return }
        whisperPipe = try? await WhisperKit(model: "small.en") 
    }

    private func transcribeWithRetry(_ msg: RadioMessage, retries: Int) {
        guard let url = msg.audioURL else {
            processTranscriptionQueue()
            return
        }
        Task {
            await loadWhisperIfNeeded()
            guard let (localURL, _) = try? await URLSession.shared.download(from: url) else {
                await MainActor.run { processTranscriptionQueue() }
                return
            }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mp3")
            try? FileManager.default.moveItem(at: localURL, to: tempURL)

            let result = try? await whisperPipe?.transcribe(audioPath: tempURL.path)
            try? FileManager.default.removeItem(at: tempURL)

            await MainActor.run {
                if let segments = result,
                   let i = self.radioMessages.firstIndex(where: { $0.id == msg.id }) {
                    let fullText = segments.map(\.text).joined()
                    if !fullText.isEmpty {
                        self.radioMessages[i].transcription = fullText
                    }
                }
                self.processTranscriptionQueue()
            }
        }
    }
    
//    private func transcribeWithRetry(_ msg: RadioMessage, retries: Int) {
//        guard let url = msg.audioURL else {
//            processTranscriptionQueue()
//            return
//        }
//        
//        Task {
//            guard let (localURL, _) = try? await URLSession.shared.download(from: url) else {
//                await MainActor.run { processTranscriptionQueue() }
//                return
//            }
//            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
//            try? FileManager.default.moveItem(at: localURL, to: tempURL)
//            
//            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB")),
//                  recognizer.isAvailable else {
//                await MainActor.run { processTranscriptionQueue() }
//                return
//            }
//            
////            let request = SFSpeechURLRecognitionRequest(url: tempURL)
////            request.shouldReportPartialResults = false
//            
//            let request = SFSpeechURLRecognitionRequest(url: tempURL)
//            request.shouldReportPartialResults = false
//
//            if #available(iOS 16, *) {
//                request.addsPunctuation = true
//            }
//
//            if #available(iOS 13, *) {
//                request.requiresOnDeviceRecognition = false
//            }
//            
//            let result: String? = await withCheckedContinuation { continuation in
//                var resumed = false
//                recognizer.recognitionTask(with: request) { result, error in
//                    guard !resumed else { return }
//                    if let result, result.isFinal {
//                        resumed = true
//                        continuation.resume(returning: result.bestTranscription.formattedString)
//                    } else if let error {
//                        resumed = true
//                        continuation.resume(returning: nil)
//                        if retries > 0 {
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                                self.transcribeWithRetry(msg, retries: retries - 1)
//                            }
//                        }
//                    }
//                }
//            }
//            if let text = result {
//                print("✅ transcription: \(text)")
//            } else {
//                print("❌ transcription returned nil")
//            }
//            
//            try? FileManager.default.removeItem(at: tempURL)
//            
//            await MainActor.run {
//                if let text = result, let i = self.radioMessages.firstIndex(where: { $0.id == msg.id }) {
//                    self.radioMessages[i].transcription = text
//                }
//                if result != nil || retries == 0 {
//                    self.processTranscriptionQueue()
//                }
//            }
//        }
//    }
    
    private func enqueue(topic: String, payload: [String: Any]) {
        guard delaySeconds > 0 else {
            handle(topic: topic, payload: payload)
            return
        }
        buffer.append((Date().addingTimeInterval(delaySeconds), topic, payload))
    }

    private func flushDue() {
        if delaySeconds > 0, let nextRelease = buffer.first?.releaseAt {
            let gap = nextRelease.timeIntervalSince(Date())
            isDelayRampingUp = gap > 1   // more than a normal flush tick's worth of nothing due
            delayRampRemaining = max(0, gap)
        } else {
            isDelayRampingUp = false
            delayRampRemaining = 0
        }

        guard !buffer.isEmpty else { return }
        let now = Date()
        var i = 0
        while i < buffer.count, buffer[i].releaseAt <= now {
            i += 1
        }
        guard i > 0 else { return }
        let ready = buffer[0..<i]
        buffer.removeFirst(i)
        for item in ready {
            handle(topic: item.topic, payload: item.payload)
        }
    }
    
    func goLive() {
        let pending = buffer
        buffer.removeAll()
        for item in pending {
            handle(topic: item.topic, payload: item.payload)
        }
    }
    
    func setDelay(_ seconds: TimeInterval) {
        delaySeconds = seconds
        if seconds == 0 {
            goLive()
        }
    }
    
    private func processRaceControl(_ payload: [String: Any]) {
        var msgs: [[String: Any]] = []
        if let arr = payload["Messages"] as? [[String: Any]] {
            msgs = arr
        } else if let dict = payload["Messages"] as? [String: Any] {
            msgs = dict.values.compactMap { $0 as? [String: Any] }
        }
        guard !msgs.isEmpty else { return }

        for m in msgs {
            guard let utc = m["Utc"] as? String,
                  let message = m["Message"] as? String else { continue }

            let id = utc + message // Utc alone can repeat within the same second
            guard !raceControlMessages.contains(where: { $0.id == id }) else { continue }

            let rc = RaceControlMessage(
                id: id,
                utc: utc,
                lap: m["Lap"] as? Int,
                category: m["Category"] as? String ?? "Other",
                message: message,
                flag: m["Flag"] as? String,
                scope: m["Scope"] as? String,
                sector: m["Sector"] as? Int,
                driverNumber: m["RacingNumber"] as? String
            )
            raceControlMessages.insert(rc, at: 0)
            enqueueToast(.raceControl(rc.id))
        }
    }
    
    func enqueueToast(_ toast: ToastKind) {
        toastQueue.append(toast)
        advanceToastIfNeeded()
    }

    func advanceToastIfNeeded() {
        guard currentToast == nil, !toastQueue.isEmpty else { return }
        currentToast = toastQueue.removeFirst()
        toastTimer?.cancel()
        toastTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s per toast
            await MainActor.run {
                self?.currentToast = nil
                self?.advanceToastIfNeeded()
            }
        }
    }
}
