//
//  LapReplayViewModel.swift
//  Redline
//
//  Created by Riley Koo on 8/27/26.
//

import Combine
import CoreLocation
import Foundation
import MapKit
import SwiftUI

/// An MKPolyline that additionally carries the color it should be rendered with, so a lap
/// can be drawn as many short polylines (one per throttle/brake "bucket") instead of one
/// flat-colored line. See LapReplayMapView's renderer for how `color` is consumed.
final class ColoredPolyline: MKPolyline {
    var color: UIColor = .white
}

/// A point annotation for one driver's live position dot. Subclassing MKPointAnnotation
/// keeps its `coordinate` KVO-compliant, so updating it every playback tick smoothly moves
/// the existing annotation view instead of requiring a remove/re-add each frame.
final class DriverDotAnnotation: MKPointAnnotation {
    let driverID: String
    let color: UIColor

    init(driverID: String, color: UIColor) {
        self.driverID = driverID
        self.color = color
        super.init()
        title = driverID
    }
}

@MainActor
class LapReplayViewModel: ObservableObject {
    let session: F1PredictorSession

    /// One driver's full replay track: a georeferenced path + a queryable timeline.
    struct DriverTrace: Identifiable {
        let id: String              // label, e.g. "#1 L23"
        let driverNumber: Int
        let color: Color
        var path: [CLLocationCoordinate2D] = []
        var positions: [(elapsed: Double, coordinate: CLLocationCoordinate2D)] = []
        var telemetry: [(elapsed: Double, speed: Int?, throttle: Int?, brake: Int?, gear: Int?)] = []
    }

    struct LiveReadout: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let color: Color
        let speed: Int?
        let throttle: Int?
        let brake: Int?
        let gear: Int?
    }

    @Published var traces: [DriverTrace] = []
    @Published var coloredPolylines: [ColoredPolyline] = []
    @Published var dotAnnotations: [DriverDotAnnotation] = []
    /// The region that fits the whole loaded track. Used for the un-zoomed camera and as a
    /// fallback if georeferencing hasn't resolved yet.
    @Published var fullTrackRegion: MKCoordinateRegion?
    @Published var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published var isPlaying: Bool = false
    @Published var playbackSpeed: Double = 1.0
    @Published var isLoading = false
    @Published var error: String?
    /// Set once the OSM fit completes; non-nil lets the UI show a "map alignment is
    /// approximate" hint with the residual if it's unusually high.
    @Published var georeferenceResidualMeters: Double?

    private var timerCancellable: AnyCancellable?
    private var lastTick: Date?

    private static let palette: [Color] = [.red, .blue, .green, .orange, .purple, .yellow]
    private static let paletteUIColor: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemYellow]

    init(session: F1PredictorSession) {
        self.session = session
    }

    func loadLaps(_ laps: [F1Lap]) async {
        isLoading = true
        error = nil
        pause()
        currentTime = 0

        // Stage 1: fetch raw telemetry-space positions (arbitrary local units) per lap.
        struct RawTrace {
            let id: String
            let driverNumber: Int
            let color: Color
            let uiColor: UIColor
            var rawPositions: [(elapsed: Double, point: CGPoint)] = []
            var telemetry: [(elapsed: Double, speed: Int?, throttle: Int?, brake: Int?, gear: Int?)] = []
        }

        var rawTraces: [RawTrace] = []
        var maxDuration: Double = 0

        for (index, lap) in laps.enumerated() {
            guard let start = lap.dateStart, let lapDuration = lap.lapDuration else { continue }
            let end = start.addingTimeInterval(lapDuration)
            let label = "#\(lap.driverNumber) L\(lap.lapNumber)"
            let color = Self.palette[index % Self.palette.count]
            let uiColor = Self.paletteUIColor[index % Self.paletteUIColor.count]

            do {
                async let locationTask = LapPositionParser.fetchLive(
                    sessionKey: "\(session.sessionKey)",
                    driverNumber: lap.driverNumber,
                    dateStart: start,
                    dateEnd: end
                )
                async let carDataTask = F1CarDataParser.fetchLive(
                    sessionKey: "\(session.sessionKey)",
                    driverNumber: lap.driverNumber,
                    dateStart: start,
                    dateEnd: end
                )

                let (rawLocations, rawCarData) = try await (locationTask, carDataTask)
                guard !rawLocations.isEmpty else { continue }

                let sortedLocations = rawLocations.sorted { $0.date < $1.date }
                let rawPositions = sortedLocations.map {
                    (elapsed: $0.date.timeIntervalSince(start), point: CGPoint(x: $0.x, y: $0.y))
                }
                let telemetry = rawCarData
                    .sorted { $0.date < $1.date }
                    .map {
                        (elapsed: $0.date.timeIntervalSince(start), speed: $0.speed,
                         throttle: $0.throttle, brake: $0.brake, gear: $0.nGear)
                    }

                var raw = RawTrace(id: label, driverNumber: lap.driverNumber, color: color, uiColor: uiColor)
                raw.rawPositions = rawPositions
                raw.telemetry = telemetry
                rawTraces.append(raw)
                maxDuration = max(maxDuration, lapDuration)
            } catch {
                self.error = error.localizedDescription
            }
        }

        guard !rawTraces.isEmpty else {
            isLoading = false
            return
        }

        // Stage 2: georeference against OpenStreetMap, anchored to the circuit's known
        // real-world start/finish coordinate. The anchor telemetry point is the very first
        // sample of the first loaded lap (elapsed == 0) -- i.e. the car crossing the
        // start/finish line, which is what TrackAnchors' coordinates represent.
        let pooledPoints = rawTraces.flatMap { $0.rawPositions.map(\.point) }
        let georef: TrackGeoreference?
        if let anchorPoint = rawTraces.first?.rawPositions.first?.point {
            do {
                let circuit = session.location.lowercased().replacingOccurrences(of: " ", with: "-")
                georef = try await TrackGeoreferencer.shared.georeference(
                    circuitName: circuit,
                    anchorTelemetryPoint: anchorPoint,
                    telemetryPoints: pooledPoints
                )
            } catch {
                self.error = "Couldn't align this lap to a real map (\(error.localizedDescription)). Showing telemetry shape only."
                georef = nil
            }
        } else {
            self.error = "No telemetry samples to anchor against."
            georef = nil
        }
        georeferenceResidualMeters = georef?.fitResidual
        if let georef {
            print("[geo] transform residual=\(georef.fitResidual)m scale=\(georef.scale) rotation=\(georef.rotation) mirror=\(georef.mirrorX)")
        }

        // Stage 3: convert every raw point into a real coordinate and build the trace list.
        var finalTraces: [DriverTrace] = []
        for raw in rawTraces {
            let coordinates: [CLLocationCoordinate2D]
            if let georef {
                coordinates = raw.rawPositions.map { georef.coordinate(for: $0.point) }
            } else {
                // Fallback: no OSM fit available (offline, geocode miss, etc). Fabricate a
                // small lat/long box from the raw shape so the app still renders *something*
                // on the map, centered near null island's degenerate case avoided via a
                // fixed placeholder origin.
                coordinates = raw.rawPositions.map {
                    CLLocationCoordinate2D(latitude: Double($0.point.y) * 0.00001,
                                            longitude: Double($0.point.x) * 0.00001)
                }
            }
            var trace = DriverTrace(id: raw.id, driverNumber: raw.driverNumber, color: raw.color)
            trace.path = coordinates
            trace.positions = zip(raw.rawPositions.map(\.elapsed), coordinates).map { (elapsed: $0, coordinate: $1) }
            trace.telemetry = raw.telemetry
            finalTraces.append(trace)
        }

        traces = finalTraces
        coloredPolylines = Self.buildColoredPolylines(finalTraces)
        dotAnnotations = zip(finalTraces, rawTraces).map { trace, raw in
            DriverDotAnnotation(driverID: trace.id, color: raw.uiColor)
        }
        fullTrackRegion = Self.regionFitting(coordinates: finalTraces.flatMap(\.path), paddingFactor: 1.15)
        duration = maxDuration
        isLoading = false
    }

    /// Groups each trace's samples into contiguous runs that share a throttle/brake color
    /// "bucket", and turns each run into its own colored polyline. Bucketing (rather than a
    /// unique color per segment) keeps the overlay count in the dozens-to-low-hundreds per
    /// lap instead of thousands, which is what MKMapView needs to stay smooth.
    private static func buildColoredPolylines(_ traces: [DriverTrace]) -> [ColoredPolyline] {
        var result: [ColoredPolyline] = []

        for trace in traces {
            guard trace.path.count > 1, !trace.telemetry.isEmpty else { continue }

            var runCoordinates: [CLLocationCoordinate2D] = [trace.path[0]]
            var runColor: UIColor?

            func flushRun() {
                guard runCoordinates.count > 1, let color = runColor else { return }
                let line = ColoredPolyline(coordinates: runCoordinates, count: runCoordinates.count)
                line.color = color
                result.append(line)
            }

            for i in 0..<(trace.path.count - 1) {
                let sample = nearestTelemetry(trace.telemetry, at: trace.positions[i].elapsed)
                let color = telemetryColor(throttle: sample?.throttle, brake: sample?.brake)

                if runColor == nil { runColor = color }
                if color != runColor {
                    flushRun()
                    runCoordinates = [trace.path[i]]
                    runColor = color
                }
                runCoordinates.append(trace.path[i + 1])
            }
            flushRun()
        }
        return result
    }

    private static func telemetryColor(throttle: Int?, brake: Int?) -> UIColor {
        if let brake, brake > 0 {
            let intensity = min(max(CGFloat(brake) / 100.0, 0.35), 1.0)
            return UIColor(red: intensity, green: 0.05, blue: 0.05, alpha: 1)
        }
        if let throttle, throttle > 0 {
            let intensity = min(max(CGFloat(throttle) / 100.0, 0.25), 1.0)
            return UIColor(red: 0.05, green: intensity, blue: 0.05, alpha: 1)
        }
        return UIColor(white: 0.55, alpha: 1) // coasting
    }

    /// A padded MKCoordinateRegion enclosing every coordinate given, with a floor on span so
    /// a single-point or tiny-span case doesn't zoom in to nothing.
    private static func regionFitting(coordinates: [CLLocationCoordinate2D], paddingFactor: Double) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let minSpan = 0.002 // ~200m floor, in degrees
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * paddingFactor, minSpan),
            longitudeDelta: max((maxLon - minLon) * paddingFactor, minSpan)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Playback

    func play() {
        guard duration > 0 else { return }
        if currentTime >= duration { currentTime = 0 }
        isPlaying = true
        lastTick = Date()
        timerCancellable = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.advance(to: now)
            }
    }

    func pause() {
        isPlaying = false
        timerCancellable?.cancel()
        timerCancellable = nil
        lastTick = nil
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func scrub(to time: Double) {
        pause()
        currentTime = min(max(time, 0), duration)
    }

    func restart() {
        pause()
        currentTime = 0
        play()
    }

    private func advance(to now: Date) {
        guard let last = lastTick else { lastTick = now; return }
        let delta = now.timeIntervalSince(last) * playbackSpeed
        lastTick = now
        currentTime += delta
        if currentTime >= duration {
            currentTime = duration
            pause()
        }
        syncDotAnnotations()
    }

    /// Moves the persistent DriverDotAnnotation instances to the interpolated position for
    /// `currentTime`. Mutating `.coordinate` in place (rather than replacing the annotation
    /// array) lets MapKit animate the marker smoothly without a remove/re-add each tick.
    private func syncDotAnnotations() {
        for readout in liveReadouts() {
            if let annotation = dotAnnotations.first(where: { $0.driverID == readout.id }) {
                annotation.coordinate = readout.coordinate
            }
        }
    }

    // MARK: - Interpolated readouts for the current scrub position

    func liveReadouts() -> [LiveReadout] {
        traces.map { trace in
            let coordinate = Self.interpolateCoordinate(trace.positions, at: currentTime)
                ?? trace.path.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
            let sample = Self.nearestTelemetry(trace.telemetry, at: currentTime)
            return LiveReadout(
                id: trace.id, coordinate: coordinate, color: trace.color,
                speed: sample?.speed, throttle: sample?.throttle,
                brake: sample?.brake, gear: sample?.gear
            )
        }
    }

    /// Linear interpolation between the two nearest samples, done in flat lat/long space.
    /// Over a single-lap timescale the great-circle vs. straight-line difference is
    /// negligible, so a straight lerp is fine here.
    private static func interpolateCoordinate(
        _ series: [(elapsed: Double, coordinate: CLLocationCoordinate2D)], at time: Double
    ) -> CLLocationCoordinate2D? {
        guard let first = series.first, let last = series.last else { return nil }
        if time <= first.elapsed { return first.coordinate }
        if time >= last.elapsed { return last.coordinate }

        var lo = 0, hi = series.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if series[mid].elapsed < time { lo = mid + 1 } else { hi = mid }
        }
        guard lo > 0 else { return series[0].coordinate }
        let p0 = series[lo - 1], p1 = series[lo]
        let span = p1.elapsed - p0.elapsed
        let frac = span > 0 ? (time - p0.elapsed) / span : 0
        return CLLocationCoordinate2D(
            latitude: p0.coordinate.latitude + (p1.coordinate.latitude - p0.coordinate.latitude) * frac,
            longitude: p0.coordinate.longitude + (p1.coordinate.longitude - p0.coordinate.longitude) * frac
        )
    }

    // MARK: - Chart data (throttle/brake/gear traces) -- unchanged by the georeferencing switch

    struct ChartSample: Identifiable {
        let id = UUID()
        let label: String
        let elapsed: Double
        let throttle: Int?
        let brake: Int?
        let gear: Int?
    }

    var chartSamples: [ChartSample] {
        traces.flatMap { trace in
            trace.telemetry.map {
                ChartSample(label: trace.id, elapsed: $0.elapsed, throttle: $0.throttle,
                            brake: $0.brake, gear: $0.gear)
            }
        }
    }

    var traceColors: [String: Color] {
        Dictionary(uniqueKeysWithValues: traces.map { ($0.id, $0.color) })
    }

    private static func nearestTelemetry(
        _ series: [(elapsed: Double, speed: Int?, throttle: Int?, brake: Int?, gear: Int?)],
        at time: Double
    ) -> (elapsed: Double, speed: Int?, throttle: Int?, brake: Int?, gear: Int?)? {
        guard !series.isEmpty else { return nil }
        var lo = 0, hi = series.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if series[mid].elapsed < time { lo = mid + 1 } else { hi = mid }
        }
        return series[lo]
    }
}
