//
//  F1TimingClient.swift
//  LiveF1
//
//  Created by Riley Koo on 6/4/26.
//


import Foundation
import Compression
import Combine

//final class WebsocketConnection {
//    static var webSocketTask: URLSessionWebSocketTask?
//}

final class F1SocketDelegate: NSObject, URLSessionWebSocketDelegate, Sendable {
    let continuation: AsyncStream<F1LiveEvent>.Continuation

    init(continuation: AsyncStream<F1LiveEvent>.Continuation) {
        self.continuation = continuation
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        continuation.yield(.state(.disconnected))
    }
}

actor F1TimingClient: F1DataSource {
//    var onMessage: ((String, [String: Any]) -> Void)?
//    var onStateChange: ((DataSourceState) -> Void)?
    
    let (stream, continuation) = AsyncStream.makeStream(of: F1LiveEvent.self)
    
    private var receiveTask: Task<Void, Never>?
    private var task: URLSessionWebSocketTask?

//    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private(set) var currentToken: String?
    
//    private var pingTimer: Timer?
    private var pingTask: Task<Void, Never>?

    private let topics = [
        "Heartbeat", "CarData.z", "Position.z", "ExtrapolatedClock",
        "TopThree", "TimingStats", "TimingAppData", "WeatherData",
        "TrackStatus", "DriverList", "RaceControlMessages",
        "SessionInfo", "SessionData", "LapCount", "TimingData", "TeamRadio",
        "SessionStatus"
    ]

//    init() {
//        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
//    }
    init() {
        let delegate = F1SocketDelegate(continuation: continuation)
        urlSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }
    
    deinit {
        continuation.finish()
        urlSession.invalidateAndCancel()
    }

    func connect(token: String?) async {
        guard task == nil else { return }
        currentToken = token
        print("🚀 connect called, token nil: \(token == nil)")
//        onStateChange?(.connecting)
        continuation.yield(.state(.connecting))
        do {
            let (connectionId, connectionToken) = try await negotiate(token: token)
            try await openWebSocket(token: token, connectionId: connectionId, connectionToken: connectionToken)
            print("🔌 sending handshake")
            try await sendHandshake()
            print("🔌 sending subscribe")
            try await subscribe()
            print("🔌 done")
//            onStateChange?(.connected)
            continuation.yield(.state(.connected))
//            receiveLoop()
            guard let task = task else { return }
            startRecieving(on: task)
            
//            await MainActor.run {
//                pingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
////                    self?.webSocketTask?.sendPing { error in
//                    WebsocketConnection.webSocketTask?.sendPing { error in
//                        if let error {
//                            print("❌ ping failed: \(error)")
//                        } else {
//                            print("✅ ping ok")
//                        }
//                    }
//                }
//            }
            pingTask = Task {
                while !Task.isCancelled {
                    do {
                        task.sendPing {error in
                            if let error {
                                print("❌ ping failed: \(error)")
                            } else {
//                                print("✅ ping ok")
                            }
                        }
                        try await Task.sleep(for: .seconds(1))
                    } catch {
                        break
                    }
                }
            }
        } catch {
//            onStateChange?(.error(error.localizedDescription))
            continuation.yield(.state(.error(error.localizedDescription)))
            task = nil
        }
    }

    func disconnect() {
//        pingTimer?.invalidate()
//        pingTimer = nil
        pingTask?.cancel()
//        WebsocketConnection.webSocketTask?.cancel(with: .normalClosure, reason: nil)
        task?.cancel(with: .normalClosure, reason: nil)
//        onStateChange?(.disconnected)
        continuation.yield(.state(.disconnected))
//        continuation.finish()
        task = nil
    }

    private func negotiate(token: String?) async throws -> (id: String, token: String) {
        var req = URLRequest(url: URL(string: "https://livetiming.formula1.com/signalrcore/negotiate?negotiateVersion=1")!)
        req.httpMethod = "POST"
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw F1ClientError.negotiationFailed }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let id = json?["connectionId"] as? String,
              let connToken = json?["connectionToken"] as? String
        else { throw F1ClientError.negotiationFailed }
        return (id, connToken)
    }

    private func openWebSocket(token: String?, connectionId: String, connectionToken: String) async throws {
        let encodedToken = connectionToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? connectionToken
        var req = URLRequest(url: URL(string: "wss://livetiming.formula1.com/signalrcore?id=\(encodedToken)")!)
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.setValue("https://livetiming.formula1.com", forHTTPHeaderField: "Origin")
//        WebsocketConnection.webSocketTask = urlSession.webSocketTask(with: req)
        task = urlSession.webSocketTask(with: req)
        print("🔌 ws resume")
//        WebsocketConnection.webSocketTask?.resume()
        task?.resume()
        print("🔌 ws resumed")
        try await Task.sleep(nanoseconds: 500_000_000)
        print("🔌 ws after sleep")
    }
    
    private func sendHandshake() async throws {
//        try await WebsocketConnection.webSocketTask?.send(.string(#"{"protocol":"json","version":1}"# + "\u{1e}"))
        try await task?.send(.string(#"{"protocol":"json","version":1}"# + "\u{1e}"))
    }

    private func subscribe() async throws {
        let msg: [String: Any] = ["type": 1, "invocationId": "0", "target": "Subscribe", "arguments": [topics]]
        let text = String(data: try JSONSerialization.data(withJSONObject: msg), encoding: .utf8)! + "\u{1e}"
//        try await WebsocketConnection.webSocketTask?.send(.string(text))
        try await task?.send(.string(text))
    }
    
    private func startRecieving(on task: URLSessionWebSocketTask) {
        receiveTask = Task {
            while !Task.isCancelled {
                do {
                    let msg = try await task.receive()
                    if case .string(let text) = msg { await processText(text) }
                    else if case .data(let data) = msg, let text = String(data: data, encoding: .utf8) { await processText(text) }
                } catch {
                    if !Task.isCancelled {
                        continuation.yield(.state(.error(error.localizedDescription)))
                    }
                    break
                }
            }
        }
    }

//    private func receiveLoop() {
////        WebsocketConnection.webSocketTask?.receive { [weak self] result in
//        task?.receive { [weak self] result in
//            switch result {
//            case .success(let msg):
//                if case .string(let text) = msg { self?.processText(text) }
//                else if case .data(let data) = msg, let text = String(data: data, encoding: .utf8) { self?.processText(text) }
//                self?.receiveLoop()
//            case .failure(let error):
//                print("❌ ws error: \(error.localizedDescription)")
////                self?.onStateChange?(.error(error.localizedDescription))
//                self?.continuation.yield(.state(.error(error.localizedDescription)))
//            }
//        }
//    }

    private func processText(_ text: String) async {
        for frame in text.components(separatedBy: "\u{1e}").filter({ !$0.isEmpty }) {
            await processFrame(frame)
        }
    }

    private func processFrame(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? Int else { return }

        if type == 6 {
//            WebsocketConnection.webSocketTask?.send(.string(#"{"type":6}"# + "\u{1e}")) { _ in }
            try? await task?.send(.string(#"{"type":6}"# + "\u{1e}"))
            return
        }

        if type == 3 {
            if let result = json["result"] as? [String: Any] {
                for (topic, payload) in result {
                    if topic.hasSuffix(".z") {
                        if let b64 = extractBase64(payload) {
                            if let decompressed = decompress(b64) {
//                                onMessage?(topic, decompressed)
                                continuation.yield(.message(topic: topic, payload: decompressed))
                            } else {
                                print("   ❌ decompress failed")
                            }
                        } else {
                            print("   ❌ extractBase64 failed")
                        }
                    } else if let p = payload as? [String: Any] {
//                        onMessage?(topic, p)
                        continuation.yield(.message(topic: topic, payload: p))
                    }
                }
            }
            return
        }

        guard type == 1,
              let target = json["target"] as? String,
              target == "feed",
              let args = json["arguments"] as? [Any],
              args.count >= 2,
              let topicName = args[0] as? String else { return }

        if topicName.hasSuffix(".z") {
            if let b64 = extractBase64(args[1]),
               let decompressed = decompress(b64) {
//                onMessage?(topicName, decompressed)
                continuation.yield(.message(topic: topicName, payload: decompressed))
            } else {
                print("❌ failed to decompress \(topicName)")
            }
        } else if let payload = args[1] as? [String: Any] {
//            onMessage?(topicName, payload)
            continuation.yield(.message(topic: topicName, payload: payload))
        }
    }

    private func decompress(_ b64: String) -> [String: Any]? {
        guard let compressed = Data(base64Encoded: b64) else { return nil }

        let bytes = [UInt8](compressed)
        let stripped = (bytes.count > 2 && bytes[0] == 0x78) ? Data(bytes.dropFirst(2)) : compressed

        var multiplier = 20
        let maxMultiplier = 500

        while multiplier <= maxMultiplier {
            let bufSize = stripped.count * multiplier
            var output = [UInt8](repeating: 0, count: bufSize)
            let written = stripped.withUnsafeBytes { ptr -> Int in
                guard let base = ptr.baseAddress else { return -1 }
                return compression_decode_buffer(&output, bufSize, base, stripped.count, nil, COMPRESSION_ZLIB)
            }

            // If we filled the buffer exactly, it's likely truncated — grow and retry.
            if written > 0 && written < bufSize {
                if let json = try? JSONSerialization.jsonObject(with: Data(output.prefix(written))) as? [String: Any] {
                    return json
                }
                return nil
            }

            multiplier *= 4
        }

        return nil
    }
    
    private func extractBase64(_ raw: Any) -> String? {
        if let s = raw as? String { return s }
        if let dict = raw as? [String: Any] {
            return dict.values.compactMap { $0 as? String }.first
        }
        return nil
    }
}
//
//extension F1TimingClient: URLSessionWebSocketDelegate {
//    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
//                                didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
//        print("🔴 WebSocket closed: \(closeCode.rawValue)")
////        onStateChange?(.disconnected)
//        continuation.yield(.state(.disconnected))
//    }
//}

enum F1ClientError: LocalizedError {
    case negotiationFailed
    var errorDescription: String? { "SignalR negotiation failed — check your token." }
}
