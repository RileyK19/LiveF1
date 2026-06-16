# LiveF1 Strategy Predictor

An iOS app that fetches live and historical Formula 1 race data from the 
OpenF1 API and uses on-device AI to simulate and compare race strategies.

## Architecture

### Data Layer
**Models**
- `F1Lap` — single lap record including sector times, speeds, and segment 
  colour data from OpenF1
- `F1PredictorStint` — tyre stint record with compound, lap range, and 
  tyre age at start
- `F1PredictorSession` — race session metadata including circuit, country, 
  and scheduled times
- `AnnotatedLap` — derived type joining a lap with its stint's compound 
  and tyre age

**Parsers**
- `F1LapParser` — fetches and decodes laps from `/v1/laps`
- `F1PredictorStintParser` — fetches and decodes stints from `/v1/stints`
- `F1PredictorSessionParser` — fetches and decodes sessions from 
  `/v1/sessions`, filtered to Race sessions for the current year

All parsers support both callback and async/await interfaces and handle 
OpenF1's ISO8601 date format with and without fractional seconds.

### Analytics Layer

**Degradation Modelling (`DegradationModel`, `DegradationModelFactory`)**

Models tyre degradation per stint using a two-pass outlier filtering 
approach:
1. Hard filter — removes pit out laps and laps more than 7% above the 
   stint median, and skips the first 2 warm-up laps of each stint
2. Initial linear regression fit
3. Soft filter — removes laps more than 2 standard deviations from the 
   initial fit
4. Final regression refit on clean data

The `DegradationModel` protocol is designed for extensibility — the 
current `LinearDegradationModel` can be swapped for polynomial or 
exponential implementations without changing any downstream code.

**Track Evolution (`TrackEvolutionCalculator`)**

Separates track-wide grip improvement from tyre-specific degradation:
1. Computes each driver's median clean lap time for the session
2. Expresses every lap as a delta from that driver's median, normalising 
   out compound pace differences
3. Takes the per-lap-number median delta across all drivers (minimum 3 
   drivers per lap for statistical validity)
4. Fits a linear regression through the median deltas to produce a smooth 
   track evolution curve

This curve is subtracted from each driver's lap times to produce an 
adjusted degradation signal that reflects true tyre wear independent of 
improving track conditions — particularly important at street circuits 
like Monaco and Canada where track evolution dominates raw lap time trends.

**Strategy Simulation (`RaceViewModel.calculateTimeDelta`)**

Calculates the predicted time delta between the actual strategy and a 
hypothetical alternative:
- Actual total time is summed from real lap data
- Hypothetical time is predicted lap-by-lap using the degradation model 
  for each compound, with track evolution added back to produce absolute 
  time estimates
- A fixed pit stop delta (22s) is applied for each stop

### AI Layer

**Strategy Context (`StrategyContextBuilder`)**

Builds a structured natural language context for the on-device model 
including:
- The selected driver's actual stint sequence and pit laps
- All other drivers' strategies for the race
- Aggregated strategy templates grouped by stop count, with average pit 
  lap windows and most common compound sequences

**Strategy Translation (`StrategyTranslator`)**

Uses the `FoundationModels` framework (Apple Intelligence, iOS 26+) with 
a `@Generable` structured output schema to translate natural language 
strategy requests into typed `[F1PredictorStint]` arrays. The model 
performs no calculations — it only resolves natural language intent into 
structured stint data which is passed to the simulation layer.

Examples of supported queries:
- "Would a 3 stop have been faster?"
- "What if Max pitted 5 laps earlier?"
- "Show me an aggressive undercut strategy"
- "What if we used softs at the end?"

### Presentation Layer (MVVM)

**`SessionPickerViewModel`** — fetches and holds the 2026 race calendar, 
filtered to completed and upcoming Race sessions

**`RaceViewModel`** — coordinates parallel fetching of laps and stints for 
a selected session, owns all derived state including annotated laps, 
regression models, track evolution, and hypothetical strategy results

**Views**
- `SessionPickerView` — race calendar list with country, circuit, and date
- `RaceDetailView` — driver selector and host for the chart view
- `LapTimeChartView` — two-page swipeable chart:
  - Page 1: absolute lap times with per-stint regression overlays coloured 
    by compound
  - Page 2: track-evolution-adjusted delta view with a flat zero reference 
    line representing field pace, showing true tyre degradation slopes
- `StrategyAssistantView` — conversational interface for hypothetical 
  strategy queries, renders results as inline strategy comparison cards 
  showing actual vs hypothetical stint sequences and predicted time delta

## Data Source

All race data is fetched from [OpenF1](https://openf1.org), a free 
community Formula 1 API providing live and historical timing data.

## Requirements

- iOS 26+
- Apple Intelligence enabled (for strategy assistant)
- Xcode 26+
