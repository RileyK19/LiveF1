# LiveF1

A native iOS app for real-time Formula 1 timing data, built entirely in Swift without third-party dependencies.

## What it does

LiveF1 connects directly to F1's official SignalR Core live timing stream — the same data feed that powers professional tools like MultiViewer. It processes a continuous stream of timing deltas, merges them into live state, and renders a real-time timing tower with sub-second updates.

The app also transcribes team radio audio clips on-device using Apple's Speech framework, and displays FIA official documents with AI-powered summaries.

## Technical highlights

**Real-time WebSocket data pipeline**
- Connects to F1's SignalR Core endpoint, handles the full handshake and subscription flow
- Processes binary-framed delta messages (record separator delimited) at ~10 updates/second during a live session
- Deep-merges partial state patches into full session state, handling both array and dict delta formats
- Decompresses zlib-encoded telemetry topics (CarData.z, Position.z) using Apple's Compression framework

**Swift concurrency throughout**
- `async/await` for all network operations
- `@MainActor` session store ensures UI updates are always on the main thread
- Sequential transcription queue using `withCheckedContinuation` to avoid Apple Speech rate limits
- `withTaskGroup` for concurrent replay stream fetching

**Authentication**
- F1TV login via `WKWebView` with cookie extraction — no credentials ever leave F1's servers
- JWT stored in iOS Keychain using Security framework
- Graceful degradation — basic timing works without any auth, telemetry unlocks with F1TV subscription

**Data architecture**
- Protocol-based `F1DataSource` allows live and replay clients to be swapped without touching the store or views
- `F1TimingParser` is a pure function — same input always produces same output, no side effects
- Single source of truth pattern with `@Published` derived state

**On-device ML**
- Team radio MP3s downloaded and transcribed locally using `SFSpeechRecognizer`
- No data sent to third-party services

## Stack

- Swift / SwiftUI
- URLSessionWebSocketTask (no third-party WebSocket library)
- Apple Compression framework (zlib decompression)  
- AVFoundation (audio playback)
- Speech framework (on-device transcription)
- Security framework (Keychain)
- WKWebView (in-app authentication)

## Project structure

```
LiveF1/
├── DataClients/
│   ├── F1TimingClient.swift     # Live WebSocket — SignalR Core negotiation,
│   │                            # handshake, frame parsing, zlib decompression
│   └── F1ReplayClient.swift     # Historical replay — fetches .jsonStream files,
│                                # merges by timestamp, replays at configurable speed
├── DataStores/
│   ├── F1SessionStore.swift     # @MainActor source of truth — delta merging,
│   │                            # radio processing, transcription queue
│   ├── F1TimingParser.swift     # Pure parser — raw [String: Any] → typed models
│   └── TokenStore.swift         # Keychain wrapper
├── Models/
│   ├── Driver.swift             # Per-driver timing, sector, tyre state
│   ├── RadioMessage.swift       # Team radio with transcription
│   ├── CarTelemetry.swift       # Throttle, brake, speed, gear, DRS
│   └── F1DataSource.swift       # Protocol enabling live/replay swap
└── Views/
    ├── TimingTowerDetails/      # Live timing tower with mini-sectors
    ├── DriverDetails/           # Per-driver telemetry cards
    ├── RadioDetails/            # Toast notifications + radio list
    └── Menus/                   # Connection flow, settings, debug
```

## How the data pipeline works

```
F1 SignalR Server
       │
       │  WebSocket frames (record-separator delimited)
       ▼
F1TimingClient
  • Negotiates connection ID via HTTP POST
  • Opens WebSocket with Bearer auth
  • Parses SignalR frame types (1=data, 3=snapshot, 6=ping)
  • Decompresses .z topics (base64 → zlib → JSON)
  • Calls onMessage(topic, payload) for each frame
       │
       ▼
F1SessionStore  (@MainActor)
  • Deep-merges delta into rawTopics[topic]
  • Handles array/dict index merging for sector updates
  • Publishes drivers: [Driver] on every update
  • Processes radio captures, queues transcription
       │
       ▼
F1TimingParser  (pure function)
  • Reads TimingData, DriverList, TimingStats, TimingAppData
  • Produces sorted [Driver] with positions, gaps, sectors, tyres
       │
       ▼
SwiftUI Views
  • Re-render on @Published changes
  • Horizontal scroll timing tower
  • Mini-sector blocks with personal/overall best colours
  • Radio toast with live transcription
```

## Running the app

1. Clone and open `LiveF1.xcodeproj`
2. Set your development team
3. Build to a real device (WebSocket requires network access beyond simulator limits)
4. Use **Replay** mode to test with historical data — no login needed
5. Use **Live** mode during an F1 session for real-time data

No API keys, no third-party SDKs, no CocoaPods or SPM dependencies.

## What I learned building this

- Reverse-engineering an undocumented SignalR Core protocol from network traffic
- Handling F1's unusual delta merge format where arrays and dicts representing the same data structure get mixed across keyframe and stream updates
- Managing Apple Speech's concurrency constraints with a sequential task queue
- The practical tradeoffs of a fat store vs strict MVVM for real-time streaming data in SwiftUI
