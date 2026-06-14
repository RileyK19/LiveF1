//
//  F1TimingClient.swift
//  LiveF1
//
//  Created by Riley Koo on 6/4/26.
//


import Foundation
import Compression

class F1TimingClient: NSObject, F1DataSource {
    var onMessage: ((String, [String: Any]) -> Void)?
    var onStateChange: ((DataSourceState) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private(set) var currentToken: String?
    
    private var pingTimer: Timer?

    private let topics = [
        "Heartbeat", "CarData.z", "Position.z", "ExtrapolatedClock",
        "TopThree", "TimingStats", "TimingAppData", "WeatherData",
        "TrackStatus", "DriverList", "RaceControlMessages",
        "SessionInfo", "SessionData", "LapCount", "TimingData", "TeamRadio"
    ]

    override init() {
        super.init()
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    func connect(token: String?) async {
        currentToken = token
        print("🚀 connect called, token nil: \(token == nil)")
        onStateChange?(.connecting)
        do {
            let (connectionId, connectionToken) = try await negotiate(token: token)
            try await openWebSocket(token: token, connectionId: connectionId, connectionToken: connectionToken)
            print("🔌 sending handshake")
            try await sendHandshake()
            print("🔌 sending subscribe")
            try await subscribe()
            print("🔌 done")
            onStateChange?(.connected)
            receiveLoop()
            
            await MainActor.run {
                pingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
                    self?.webSocketTask?.sendPing { error in
                        if let error {
                            print("❌ ping failed: \(error)")
                        } else {
                            print("✅ ping ok")
                        }
                    }
                }
            }
        } catch {
            onStateChange?(.error(error.localizedDescription))
        }
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        onStateChange?(.disconnected)
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
        webSocketTask = urlSession.webSocketTask(with: req)
        print("🔌 ws resume")
        webSocketTask?.resume()
        print("🔌 ws resumed")
        try await Task.sleep(nanoseconds: 500_000_000)
        print("🔌 ws after sleep")
    }
    
    private func sendHandshake() async throws {
        try await webSocketTask?.send(.string(#"{"protocol":"json","version":1}"# + "\u{1e}"))
    }

    private func subscribe() async throws {
        let msg: [String: Any] = ["type": 1, "invocationId": "0", "target": "Subscribe", "arguments": [topics]]
        let text = String(data: try JSONSerialization.data(withJSONObject: msg), encoding: .utf8)! + "\u{1e}"
        try await webSocketTask?.send(.string(text))
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let msg):
                if case .string(let text) = msg { self?.processText(text) }
                else if case .data(let data) = msg, let text = String(data: data, encoding: .utf8) { self?.processText(text) }
                self?.receiveLoop()
            case .failure(let error):
                print("❌ ws error: \(error.localizedDescription)")
                self?.onStateChange?(.error(error.localizedDescription))
            }
        }
    }

    private func processText(_ text: String) {
        for frame in text.components(separatedBy: "\u{1e}").filter({ !$0.isEmpty }) {
            processFrame(frame)
        }
    }

    private func processFrame(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? Int else { return }

        if type == 6 {
            webSocketTask?.send(.string(#"{"type":6}"# + "\u{1e}")) { _ in }
            return
        }

        if type == 3 {
            if let result = json["result"] as? [String: Any] {
                for (topic, payload) in result {
                    if let p = payload as? [String: Any] {
                        onMessage?(topic, p)
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
            if let payload = args[1] as? [String: Any],
               let decompressed = decompress(payload) {
                onMessage?(topicName, decompressed)
            }
        } else if let payload = args[1] as? [String: Any] {
            onMessage?(topicName, payload)
        }
    }

    private func decompress(_ payload: [String: Any]) -> [String: Any]? {
        guard let b64 = payload.values.compactMap({ $0 as? String }).first,
              let compressed = Data(base64Encoded: b64) else { return nil }

        let bytes = [UInt8](compressed)
        let stripped = (bytes.count > 2 && bytes[0] == 0x78) ? Data(bytes.dropFirst(2)) : compressed

        let bufSize = compressed.count * 10
        var output = [UInt8](repeating: 0, count: bufSize)
        let written = stripped.withUnsafeBytes { ptr -> Int in
            guard let base = ptr.baseAddress else { return -1 }
            return compression_decode_buffer(&output, bufSize, base, stripped.count, nil, COMPRESSION_ZLIB)
        }
        guard written > 0,
              let json = try? JSONSerialization.jsonObject(with: Data(output.prefix(written))) as? [String: Any]
        else { return nil }

        var result = json
        if let utc = payload["Utc"] as? String { result["Utc"] = utc }
        return result
    }
}

extension F1TimingClient: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                                didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🔴 WebSocket closed: \(closeCode.rawValue)")
        onStateChange?(.disconnected)
    }
}

enum F1ClientError: LocalizedError {
    case negotiationFailed
    var errorDescription: String? { "SignalR negotiation failed — check your token." }
}
