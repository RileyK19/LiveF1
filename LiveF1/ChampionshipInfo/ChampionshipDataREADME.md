# LiveF1 🏎️

A real-time Formula 1 companion app for iOS built with SwiftUI.

## Features

- **Live Timing** — Connect to live session data in real time
- **Replay** — Browse and replay past sessions
- **Championship Schedule** — Full 2026 season calendar with session times in your local timezone
- **Standings** — Driver and constructor championship standings with points visualizations
- **Predictor** — Lap time and strategy forecasts
- **FIA Documents** — Browse official race bulletins

## Architecture

### Data
- `ChampionshipDataStore` — ObservableObject that fetches and caches all championship data
- `F1SessionStore` — Handles live and replay session timing data
- Data sourced from the [Jolpi Ergast API](https://api.jolpi.ca/ergast/f1)
- Responses cached in `UserDefaults` with a 1-hour TTL

### Models
All championship models are prefixed with `Championship`:
- `ChampionshipRace` — Race weekend with all session dates/times
- `ChampionshipSession` — Individual session with local time formatting
- `ChampionshipDriverStanding` / `ChampionshipConstructorStanding` — Points standings
- `ChampionshipCacheEntry` — Generic cache wrapper with expiry

### Views
- `HomeView` — Dashboard with navigation to all features
- `ChampionshipScheduleView` — Season calendar with next race banner and countdown
- `ChampionshipStandingsView` — Segmented driver/constructor standings with points bars

## Setup

1. Clone the repo
2. Open `LiveF1.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build and run — no API keys required

## Requirements

- iOS 17+
- Xcode 15+
- Swift 5.9+

## API

Data is fetched from the free [Jolpi Ergast Mirror](https://api.jolpi.ca/ergast/f1):
'''
GET https://api.jolpi.ca/ergast/f1/current.json        — Season schedule

GET https://api.jolpi.ca/ergast/f1/current/driverStandings.json

GET https://api.jolpi.ca/ergast/f1/current/constructorStandings.json
'''
The `current` keyword automatically resolves to the active season, so the app works year to year without any changes.

## Caching

All responses are cached locally for 1 hour. Pull to refresh forces a network fetch and updates the cache. Cache is stored in `UserDefaults` and can be cleared via `ChampionshipDataStore.clearCache()`.
