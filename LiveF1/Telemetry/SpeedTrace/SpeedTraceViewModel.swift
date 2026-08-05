//
//  SpeedTraceViewModel.swift
//  LiveF1
//
//  Created by Riley Koo on 7/5/26.
//

import Combine
import Foundation

@MainActor
class SpeedTraceViewModel: ObservableObject {
    let session: F1PredictorSession

    struct Sample: Identifiable {
        let id = UUID()
        let label: String
        let elapsed: Double
        let speed: Int?
        let throttle: Int?
        let brake: Int?
        let gear: Int?
        var distance: Double?
        var delta: Double?
        var refElapsed: Double?
    }

    @Published var samples: [Sample] = []
    @Published var deltaSamples: [Sample] = []
    @Published var isLoading = false
    @Published var error: String?

    private var lapDurations: [String: Double] = [:]

    init(session: F1PredictorSession) {
        self.session = session
    }

    func loadLaps(_ laps: [F1Lap]) async {
        isLoading = true
        error = nil
        var all: [Sample] = []
        lapDurations = [:]

        for lap in laps {
            guard let start = lap.dateStart, let duration = lap.lapDuration else { continue }
            let label = "#\(lap.driverNumber) L\(lap.lapNumber)"
            lapDurations[label] = duration

            do {
                let raw = try await F1CarDataParser.fetchLive(
                    sessionKey: "\(session.sessionKey)",
                    driverNumber: lap.driverNumber,
                    dateStart: start,
                    dateEnd: start.addingTimeInterval(duration)
                )
                all.append(contentsOf: raw.map {
                    Sample(
                        label: label,
                        elapsed: $0.date.timeIntervalSince(start),
                        speed: $0.speed,
                        throttle: $0.throttle,
                        brake: $0.brake,
                        gear: $0.nGear
                    )
                })
            } catch {
                self.error = error.localizedDescription
            }
        }

        samples = all
        await calcDistances()
        isLoading = false
    }

    func calcDistances() async {
        let uniqueLabels = Set(samples.map(\.label))
        var rawDistances: [String: [(id: Sample.ID, distance: Double)]] = [:]

        // pass 1: raw distance per lap via speed integration (trapezoidal rule)
        for label in uniqueLabels {
            let sortedSamples = samples.sorted(by: { $0.elapsed < $1.elapsed }).filter { $0.label == label }
            var prevElapsed: Double = 0.0
            var prevSpeed: Double = 0.0
            var total: Double = 0.0
            var distances: [(id: Sample.ID, distance: Double)] = []

            for sample in sortedSamples {
                let currSpeed = Double(sample.speed ?? 0) / 3.6 // km/h -> m/s
                let avgSpeed = (prevSpeed + currSpeed) / 2.0
                let distance = avgSpeed * (sample.elapsed - prevElapsed) + total
                total = distance
                prevElapsed = sample.elapsed
                prevSpeed = currSpeed
                distances.append((sample.id, distance))
            }
            rawDistances[label] = distances
        }

        // pick reference lap = fastest by official lap duration
        guard let referenceLabel = lapDurations.min(by: { $0.value < $1.value })?.key,
              let referenceTotal = rawDistances[referenceLabel]?.last?.distance, referenceTotal > 0 else {
            for (_, distances) in rawDistances {
                for (id, distance) in distances {
                    if let index = samples.firstIndex(where: { $0.id == id }) {
                        samples[index].distance = distance
                    }
                }
            }
            calcDeltas()
            return
        }

        // pass 2: scale each lap's distance so its total matches the reference lap's total
        for (label, distances) in rawDistances {
            guard let thisTotal = distances.last?.distance, thisTotal > 0 else { continue }
            let scale = label == referenceLabel ? 1.0 : referenceTotal / thisTotal
            for (id, distance) in distances {
                if let index = samples.firstIndex(where: { $0.id == id }) {
                    samples[index].distance = distance * scale
                }
            }
        }

        calcDeltas()
    }

    func calcDeltas() {
        var tracesByLabel: [String: [(distance: Double, elapsed: Double)]] = [:]
        for label in Set(samples.map(\.label)) {
            let sorted = samples
                .filter { $0.label == label }
                .sorted { $0.elapsed < $1.elapsed }
                .compactMap { s -> (Double, Double)? in
                    guard let d = s.distance else { return nil }
                    return (d, s.elapsed)
                }
            tracesByLabel[label] = sorted
        }

        guard let referenceLabel = lapDurations.min(by: { $0.value < $1.value })?.key,
              let referenceTrace = tracesByLabel[referenceLabel] else {
            deltaSamples = []
            return
        }

        for label in Set(samples.map(\.label)) {
            let sortedIndices = samples.indices
                .filter { samples[$0].label == label }
                .sorted { samples[$0].elapsed < samples[$1].elapsed }

            for index in sortedIndices {
                guard let distance = samples[index].distance else { continue }
                if label == referenceLabel {
                    samples[index].delta = 0
                } else if let refTime = interpolatedTime(atDistance: distance, in: referenceTrace) {
                    samples[index].delta = samples[index].elapsed - refTime
                }
            }
            
            for index in sortedIndices {
                guard let distance = samples[index].distance else { continue }
                if label == referenceLabel {
                    samples[index].delta = 0
                    samples[index].refElapsed = samples[index].elapsed
                } else if let refTime = interpolatedTime(atDistance: distance, in: referenceTrace) {
                    samples[index].delta = samples[index].elapsed - refTime
                    samples[index].refElapsed = refTime
                }
            }
        }

        deltaSamples = samples.filter { $0.distance != nil && $0.delta != nil && $0.refElapsed != nil }
    }

    /// Linear interpolation: given a distance, find elapsed time in a (distance, elapsed) trace.
    private func interpolatedTime(atDistance target: Double, in trace: [(distance: Double, elapsed: Double)]) -> Double? {
        guard let first = trace.first, let last = trace.last,
              target >= first.distance, target <= last.distance else { return nil }

        var lo = 0, hi = trace.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if trace[mid].distance < target { lo = mid + 1 } else { hi = mid }
        }
        guard lo > 0 else { return trace[0].elapsed }
        let p0 = trace[lo - 1]
        let p1 = trace[lo]
        guard p1.distance > p0.distance else { return p0.elapsed }
        let frac = (target - p0.distance) / (p1.distance - p0.distance)
        return p0.elapsed + frac * (p1.elapsed - p0.elapsed)
    }
}
