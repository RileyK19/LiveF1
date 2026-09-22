//
//  OSMTrackGeoReferencer.swift
//  Redline
//
//  Created by Riley Koo on 8/31/26.
//


import CoreGraphics
import CoreLocation
import Foundation

/// A fitted mapping from telemetry-space points to real-world coordinates for one circuit.
struct TrackGeoreference {
    let originLat: Double
    let originLon: Double
    let rotation: Double
    let scale: Double
    let mirrorX: Bool
    let translation: CGPoint   // meters, in the local plane centered on (originLat, originLon)
    let fitResidual: Double

    func coordinate(for telemetryPoint: CGPoint) -> CLLocationCoordinate2D {
        let mirrored = mirrorX ? CGPoint(x: -telemetryPoint.x, y: telemetryPoint.y) : telemetryPoint
        let scaled = CGPoint(x: mirrored.x * CGFloat(scale), y: mirrored.y * CGFloat(scale))
        let cosT = cos(rotation), sinT = sin(rotation)
        let rx = Double(scaled.x) * cosT - Double(scaled.y) * sinT
        let ry = Double(scaled.x) * sinT + Double(scaled.y) * cosT
        let mx = rx + Double(translation.x)
        let my = ry + Double(translation.y)
        return TrackGeoreferencer.unproject(x: mx, y: my, originLat: originLat, originLon: originLon)
    }
}

enum OSMTrackGeoreferencerError: Error {
    case noKnownAnchor
    case noTrackGeometry
    case insufficientPoints
}

extension OSMTrackGeoreferencerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noKnownAnchor: return "No known start/finish coordinate for this circuit -- add it to TrackAnchors"
        case .noTrackGeometry: return "Overpass returned no raceway geometry near that point"
        case .insufficientPoints: return "Fewer than 20 telemetry points were passed in"
        }
    }
}

/// Known real-world anchor coordinates, keyed by whatever string comes back in
/// `session.location` from the F1 data source. Each value should be the start/finish line
/// (or any other single point you can identify precisely and reliably match to the first
/// telemetry sample of a lap) -- NOT just "somewhere near the circuit". These values are
/// starting points; verify/refine them against OSM or a track map before trusting the fit.
///
/// TODO: fill in the rest of the calendar. Print `session.location` for a session at a
/// track not listed here and add it.
enum TrackAnchors {
    static let coordinates: [String: CLLocationCoordinate2D] = [
        "barcelona": CLLocationCoordinate2D(latitude: 41.5700, longitude: 2.2611),
        "spa-francorchamps": CLLocationCoordinate2D(latitude: 50.4372, longitude: 5.9714),
        "monza": CLLocationCoordinate2D(latitude: 45.6156, longitude: 9.2811),
        "silverstone": CLLocationCoordinate2D(latitude: 52.0786, longitude: -1.0169),
        "suzuka": CLLocationCoordinate2D(latitude: 34.8431, longitude: 136.5410),
        "monte-carlo": CLLocationCoordinate2D(latitude: 43.7328624, longitude: 7.4221705),
        "zandvoort": CLLocationCoordinate2D(latitude: 52.3888, longitude: 4.5409),
        "abu-dhabi":CLLocationCoordinate2D(latitude: 24.4675896, longitude: 54.6064803),
        "austin": CLLocationCoordinate2D(latitude: 30.1352573, longitude: -97.6403261),
        "bahrain": CLLocationCoordinate2D(latitude: 26.0295603, longitude: 50.5174496),
        "budapest": CLLocationCoordinate2D(latitude: 47.5820518, longitude: 19.2424423),
        "imola": CLLocationCoordinate2D(latitude: 44.33727, longitude: 11.710274),
        "jeddah": CLLocationCoordinate2D(latitude: 21.6389791, longitude: 39.1024422),
        "mexico-city": CLLocationCoordinate2D(latitude: 19.4037359, longitude: -99.0949224),
        "miami": CLLocationCoordinate2D(latitude: 25.9557843, longitude: -80.2371343),
        "montréal": CLLocationCoordinate2D(latitude: 45.5045625, longitude: -73.5236035),
        "são-paulo": CLLocationCoordinate2D(latitude: -23.6998857, longitude: -46.7003703),
        "spielberg": CLLocationCoordinate2D(latitude: 47.2260136, longitude: 14.7541652),
    ]
}

actor TrackGeoreferencer {
    static let shared = TrackGeoreferencer()

    private var cache: [String: TrackGeoreference] = [:]

    /// Looks up (or reuses a cached) georeference for a circuit, fitting it against the
    /// supplied telemetry point cloud, anchored to the circuit's known real-world point.
    ///
    /// - Parameters:
    ///   - anchorTelemetryPoint: the telemetry-space point known to correspond to the
    ///     circuit's real anchor coordinate -- normally the first sample of a lap
    ///     (elapsed == 0), i.e. the car crossing the start/finish line.
    ///   - telemetryPoints: the full pooled set of telemetry points (across all loaded laps)
    ///     used to determine the best rotation/scale. More points, more reliable.
    func georeference(
        circuitName: String,
        anchorTelemetryPoint: CGPoint,
        telemetryPoints: [CGPoint]
    ) async throws -> TrackGeoreference {
        guard telemetryPoints.count >= 20 else { throw OSMTrackGeoreferencerError.insufficientPoints }
        if let cached = cache[circuitName] { return cached }

        guard let anchorCoordinate = TrackAnchors.coordinates[circuitName] else {
            throw OSMTrackGeoreferencerError.noKnownAnchor
        }
        let originLat = anchorCoordinate.latitude
        let originLon = anchorCoordinate.longitude

        let trackLatLon = try await fetchRacewayGeometry(near: originLat, lon: originLon, trackID: circuitName)
        guard trackLatLon.count >= 10 else { throw OSMTrackGeoreferencerError.noTrackGeometry }
        let targetMeters = trackLatLon.map {
            project(lat: $0.lat, lon: $0.lon, originLat: originLat, originLon: originLon)
        }
        
        print("[geo] telemetry range: x", telemetryPoints.map(\.x).min()!, "to", telemetryPoints.map(\.x).max()!,
              " y", telemetryPoints.map(\.y).min()!, "to", telemetryPoints.map(\.y).max()!)
        print("[geo] anchor telemetry point:", anchorTelemetryPoint)

        let fit = Self.fitFreeTransform(source: telemetryPoints, targetPolyline: targetMeters)
        let result = TrackGeoreference(
            originLat: originLat, originLon: originLon,
            rotation: fit.rotation, scale: TrackGeoreferencer.metersPerRawUnit, mirrorX: fit.mirrorX,
            translation: fit.translation, fitResidual: fit.residual
        )
        cache[circuitName] = result
        return result
    }

    // MARK: - OpenStreetMap: track geometry only (no geocoding needed -- the anchor IS the origin)

    /// Overpass: pulls the actual raceway way geometry near the known anchor point, so the
    /// overlay follows real pavement rather than a hand-drawn approximation.
    private func fetchRacewayGeometry(near lat: Double, lon: Double, trackID: String) async throws -> [(lat: Double, lon: Double)] {

        // --- GeoJSON decoding (used for bundled files exported from overpass-turbo) ---
        struct GeoJSONFeature: Decodable {
            let geometry: GeoJSONGeometry
        }
        struct GeoJSONGeometry: Decodable {
            let points: [(lon: Double, lat: Double)]
            enum CodingKeys: String, CodingKey { case type, coordinates }
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(String.self, forKey: .type)
                switch type {
                case "LineString":
                    let coords = try container.decode([[Double]].self, forKey: .coordinates)
                    points = coords.map { (lon: $0[0], lat: $0[1]) }
                case "Polygon":
                    let coords = try container.decode([[[Double]]].self, forKey: .coordinates)
                    let ring = coords.first ?? []
                    points = ring.map { (lon: $0[0], lat: $0[1]) }
                default:
                    points = []
                }
            }
        }
        struct GeoJSONResponse: Decodable {
            let features: [GeoJSONFeature]
        }

        // --- Raw Overpass JSON decoding (used for the live API fallback) ---
        struct OverpassGeom: Decodable { let lat: Double; let lon: Double }
        struct OverpassElement: Decodable { let geometry: [OverpassGeom]? }
        struct OverpassResponse: Decodable { let elements: [OverpassElement] }

        // 1. Try the bundled GeoJSON first.
        let foundURL = Bundle.main.url(forResource: trackID, withExtension: "json")
        print("[geo] bundle lookup for \(trackID):", foundURL?.absoluteString ?? "not found")

        if let url = foundURL {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(GeoJSONResponse.self, from: data)
                let ways = decoded.features.map { $0.geometry.points }
                if let longest = ways.max(by: { $0.count < $1.count }) {
                    print("[geo] using bundled geometry for \(trackID), \(longest.count) points")
                    return longest.map { (lat: $0.lat, lon: $0.lon) } // swap back to lat/lon order
                }
            } catch {
                print("[geo] bundle file found but failed to decode as GeoJSON:", error)
            }
        }
        
        // 3. Last resort: tag-based search near the anchor point.
        let query = """
        [out:json][timeout:25];
        (
          way(around:4000,\(lat),\(lon))["highway"="raceway"];
          way(around:4000,\(lat),\(lon))["leisure"="track"]["sport"="motor"];
        );
        out geom;
        """

        let overpassServers = [
            "https://overpass.kumi.systems/api/interpreter",
            "https://overpass.private.coffee/api/interpreter",
            "https://z.overpass-api.de/api/interpreter"
        ]

        var lastError: Error = OSMTrackGeoreferencerError.noTrackGeometry

        for server in overpassServers {
            var components = URLComponents(string: server)!
            components.queryItems = [URLQueryItem(name: "data", value: query)]
            var request = URLRequest(url: components.url!)
            request.httpMethod = "GET"
            request.setValue("Redline/1.0 (F1 lap replay overlay; contact: your-real-email@example.com)",
                              forHTTPHeaderField: "User-Agent")
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    lastError = NSError(domain: "Overpass", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
                    continue
                }
                let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
                let ways = decoded.elements.compactMap { $0.geometry }
                guard let longest = ways.max(by: { $0.count < $1.count }) else {
                    lastError = OSMTrackGeoreferencerError.noTrackGeometry
                    continue
                }
                return longest.map { (lat: $0.lat, lon: $0.lon) }
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError
    }

//    private func fetchRacewayGeometry(near lat: Double, lon: Double, trackID: String) async throws -> [(lat: Double, lon: Double)] {
//
//        // 1. Cache.
//        if let cached = GeometryCache.load(trackID: trackID) {
//            print("[geo] cache hit for \(trackID), \(cached.count) points")
//            return cached
//        }
//
//        // 2. Known way IDs, queried directly by ID (deterministic, no tag-match ambiguity).
//        if let ids = TrackWayIDs.ids[trackID], !ids.isEmpty {
//            do {
//                let stitched = try await fetchWaysByID(ids)
//                GeometryCache.save(stitched, trackID: trackID)
//                print("[geo] fetched by way ID for \(trackID), \(stitched.count) points")
//                return stitched
//            } catch {
//                print("[geo] by-ID fetch failed for \(trackID), falling back to tag search:", error)
//            }
//        }
//
//        // 3. Last resort: tag-based search near the anchor point.
//        struct OverpassGeom: Decodable { let lat: Double; let lon: Double }
//        struct OverpassElement: Decodable { let geometry: [OverpassGeom]? }
//        struct OverpassResponse: Decodable { let elements: [OverpassElement] }
//
//        let query = """
//        [out:json][timeout:25];
//        (
//          way(around:4000,\(lat),\(lon))["highway"="raceway"];
//          way(around:4000,\(lat),\(lon))["leisure"="track"]["sport"="motor"];
//        );
//        out geom;
//        """
//
//        let overpassServers = [
//            "https://overpass.kumi.systems/api/interpreter",
//            "https://overpass.private.coffee/api/interpreter",
//            "https://z.overpass-api.de/api/interpreter"
//        ]
//
//        var lastError: Error = OSMTrackGeoreferencerError.noTrackGeometry
//
//        for server in overpassServers {
//            var components = URLComponents(string: server)!
//            components.queryItems = [URLQueryItem(name: "data", value: query)]
//            var request = URLRequest(url: components.url!)
//            request.httpMethod = "GET"
//            request.setValue("Redline/1.0 (F1 lap replay overlay; contact: your-real-email@example.com)",
//                              forHTTPHeaderField: "User-Agent")
//            do {
//                let (data, response) = try await URLSession.shared.data(for: request)
//                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
//                    lastError = NSError(domain: "Overpass", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
//                    continue
//                }
//                let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
//                let ways = decoded.elements.compactMap { $0.geometry }
//                guard let longest = ways.max(by: { $0.count < $1.count }) else {
//                    lastError = OSMTrackGeoreferencerError.noTrackGeometry
//                    continue
//                }
//                let points = longest.map { (lat: $0.lat, lon: $0.lon) }
//                GeometryCache.save(points, trackID: trackID)
//                print("[geo] fetched by tag search for \(trackID), \(points.count) points")
//                return points
//            } catch {
//                lastError = error
//                continue
//            }
//        }
//
//        throw lastError
//    }
    
    // MARK: - Flat-plane projection (equirectangular; accurate over track-sized areas)

    nonisolated static func unproject(x: Double, y: Double, originLat: Double, originLon: Double) -> CLLocationCoordinate2D {
        let metersPerDegLat = 111_320.0
        let metersPerDegLon = 111_320.0 * cos(originLat * .pi / 180)
        let lat = originLat + y / metersPerDegLat
        let lon = originLon + x / metersPerDegLon
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func project(lat: Double, lon: Double, originLat: Double, originLon: Double) -> CGPoint {
        let metersPerDegLat = 111_320.0
        let metersPerDegLon = 111_320.0 * cos(originLat * .pi / 180)
        return CGPoint(x: (lon - originLon) * metersPerDegLon, y: (lat - originLat) * metersPerDegLat)
    }

    // MARK: - Anchored shape registration

    private struct SimilarityFit {
        var rotation: Double
        var scale: Double
        var mirrorX: Bool
        var residual: Double
    }

    /// Similarity transform: localMeters = 0.1 * R(rotation) * mirror(telemetryPoint - anchorTelemetry)
    /// Scale is fixed, not fitted: OpenF1's /location endpoint returns X/Y in decimeters
    /// (tenths of a meter), a documented/known convention -- confirmed by checking sample
    /// data (consecutive points imply ~48 m/s only when divided by 10; ~480 m/s otherwise,
    /// which is physically impossible). Only rotation/mirror are genuinely unknown per venue.
    private static let metersPerRawUnit = 0.1

    private static func fitFreeTransform(
        source: [CGPoint], targetPolyline: [CGPoint]
    ) -> (rotation: Double, translation: CGPoint, mirrorX: Bool, residual: Double) {
        let sample = downsample(source, maxCount: 400)

        var best: (rotation: Double, translation: CGPoint, mirrorX: Bool, residual: Double)?
        for mirror in [false, true] {
            var angle = 0.0
            while angle < 2 * Double.pi {
                let candidate = refineTranslation(source: sample, target: targetPolyline, rotation: angle, mirrorX: mirror)
                if best == nil || candidate.residual < best!.residual { best = candidate }
                angle += .pi / 90 // 2-degree steps
            }
        }
        return best!
    }

    /// For a fixed rotation/mirror, finds the best translation via ICP: seed translation by
    /// aligning centroids, then iteratively re-match nearest points and re-center.
    private static func refineTranslation(
        source: [CGPoint], target: [CGPoint], rotation: Double, mirrorX: Bool, iterations: Int = 8
    ) -> (rotation: Double, translation: CGPoint, mirrorX: Bool, residual: Double) {
        func mirror(_ p: CGPoint) -> CGPoint { mirrorX ? CGPoint(x: -p.x, y: p.y) : p }
        let cosT = cos(rotation), sinT = sin(rotation)
        func rotate(_ p: CGPoint) -> CGPoint {
            CGPoint(x: CGFloat(Double(p.x) * cosT - Double(p.y) * sinT),
                    y: CGFloat(Double(p.x) * sinT + Double(p.y) * cosT))
        }

        let placed = source.map { rotate(CGPoint(x: mirror($0).x * CGFloat(metersPerRawUnit),
                                                  y: mirror($0).y * CGFloat(metersPerRawUnit))) }

        // Seed translation from centroid alignment.
        let sourceCentroid = CGPoint(x: placed.map(\.x).reduce(0, +) / CGFloat(placed.count),
                                      y: placed.map(\.y).reduce(0, +) / CGFloat(placed.count))
        let targetCentroid = CGPoint(x: target.map(\.x).reduce(0, +) / CGFloat(target.count),
                                      y: target.map(\.y).reduce(0, +) / CGFloat(target.count))
        var translation = CGPoint(x: targetCentroid.x - sourceCentroid.x, y: targetCentroid.y - sourceCentroid.y)

        var lastResidual = Double.infinity
        for _ in 0..<iterations {
            let transformed = placed.map { CGPoint(x: $0.x + translation.x, y: $0.y + translation.y) }
            let correspondences = transformed.map { nearestPoint(to: $0, on: target) }

            // Re-center: new translation = mean(correspondence - placed)
            let dx = zip(correspondences, placed).map { $0.x - $1.x }.reduce(0, +) / CGFloat(placed.count)
            let dy = zip(correspondences, placed).map { $0.y - $1.y }.reduce(0, +) / CGFloat(placed.count)
            translation = CGPoint(x: dx, y: dy)

            let residual = zip(transformed, correspondences)
                .map { Double(hypot($0.x - $1.x, $0.y - $1.y)) }
                .reduce(0, +) / Double(max(placed.count, 1))
            if abs(lastResidual - residual) < 1e-4 { lastResidual = residual; break }
            lastResidual = residual
        }

        return (rotation: rotation, translation: translation, mirrorX: mirrorX, residual: lastResidual)
    }

    /// Nearest point to `p` on the polyline `target`, restricted to a window of indices around
    /// `hintIndex` (when provided) to avoid snapping onto a geometrically-close-but-wrong
    /// parallel section of track (e.g. front straight vs. pit straight near start/finish).
    private static func nearestPoint(to p: CGPoint, on target: [CGPoint]) -> CGPoint {
        guard target.count > 1 else { return target.first ?? .zero }
        var best = target[0]
        var bestDist = Double.infinity
        for i in 0..<(target.count - 1) {
            let candidate = closestPointOnSegment(p, target[i], target[i + 1])
            let d = Double(hypot(candidate.x - p.x, candidate.y - p.y))
            if d < bestDist { bestDist = d; best = candidate }
        }
        return best
    }

    private static func closestPointOnSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let lengthSq = Double(ab.x * ab.x + ab.y * ab.y)
        guard lengthSq > 1e-9 else { return a }
        let t = max(0, min(1, Double((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / lengthSq))
        return CGPoint(x: a.x + ab.x * CGFloat(t), y: a.y + ab.y * CGFloat(t))
    }

    private static func downsample(_ points: [CGPoint], maxCount: Int) -> [CGPoint] {
        guard points.count > maxCount else { return points }
        let step = Double(points.count) / Double(maxCount)
        return (0..<maxCount).map { points[Int(Double($0) * step)] }
    }
    
    // TEMP
    static func testAffineFit(deviations: [CGPoint], target: [CGPoint]) {
        let correspondences = deviations.map { nearestPoint(to: $0, on: target) }

        var numX = 0.0, denX = 0.0, numY = 0.0, denY = 0.0
        for i in 0..<deviations.count {
            numX += Double(deviations[i].x) * Double(correspondences[i].x)
            denX += Double(deviations[i].x) * Double(deviations[i].x)
            numY += Double(deviations[i].y) * Double(correspondences[i].y)
            denY += Double(deviations[i].y) * Double(deviations[i].y)
        }
        let scaleX = denX > 1e-9 ? numX / denX : 1.0
        let scaleY = denY > 1e-9 ? numY / denY : 1.0

        let transformed = deviations.map { CGPoint(x: CGFloat(Double($0.x) * scaleX), y: CGFloat(Double($0.y) * scaleY)) }
        let residual = transformed
            .map { Double(hypot($0.x - nearestPoint(to: $0, on: target).x, $0.y - nearestPoint(to: $0, on: target).y)) }
            .reduce(0, +) / Double(max(transformed.count, 1))

        print("[geo] AFFINE TEST: scaleX=\(scaleX) scaleY=\(scaleY) residual=\(residual)")
    }
    
//    private func fetchWaysByID(_ ids: [Int64]) async throws -> [(lat: Double, lon: Double)] {
//        struct OverpassGeom: Decodable { let lat: Double; let lon: Double }
//        struct OverpassElement: Decodable { let id: Int64; let geometry: [OverpassGeom]? }
//        struct OverpassResponse: Decodable { let elements: [OverpassElement] }
//
//        let idList = ids.map(String.init).joined(separator: ",")
//        let query = "[out:json][timeout:25];way(id:\(idList));out geom;"
//
//        let overpassServers = [
//            "https://overpass.kumi.systems/api/interpreter",
//            "https://overpass.private.coffee/api/interpreter",
//            "https://z.overpass-api.de/api/interpreter"
//        ]
//
//        var lastError: Error = OSMTrackGeoreferencerError.noTrackGeometry
//
//        for server in overpassServers {
//            var components = URLComponents(string: server)!
//            components.queryItems = [URLQueryItem(name: "data", value: query)]
//            var request = URLRequest(url: components.url!)
//            request.httpMethod = "GET"
////            request.setValue("Redline/1.0 (F1 lap replay overlay; contact: your-real-email@example.com)",
////                              forHTTPHeaderField: "User-Agent")
//            do {
//                let (data, response) = try await URLSession.shared.data(for: request)
//                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
//                    lastError = NSError(domain: "Overpass", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
//                    continue
//                }
//                let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
//                let byID = Dictionary(uniqueKeysWithValues: decoded.elements.compactMap { el -> (Int64, [(lat: Double, lon: Double)])? in
//                    guard let geom = el.geometry else { return nil }
//                    return (el.id, geom.map { (lat: $0.lat, lon: $0.lon) })
//                })
//                let ways = ids.compactMap { byID[$0] } // preserve the order you supplied
//                guard !ways.isEmpty else {
//                    lastError = OSMTrackGeoreferencerError.noTrackGeometry
//                    continue
//                }
//                return Self.stitchWays(ways)
//            } catch {
//                lastError = error
//                continue
//            }
//        }
//
//        throw lastError
//    }
//
//    private static func stitchWays(_ ways: [[(lat: Double, lon: Double)]]) -> [(lat: Double, lon: Double)] {
//        guard var chain = ways.first else { return [] }
//        var remaining = Array(ways.dropFirst())
//        while !remaining.isEmpty {
//            guard let last = chain.last else { break }
//            var bestIdx = 0, bestReversed = false, bestDist = Double.infinity
//            for (i, way) in remaining.enumerated() {
//                guard let first = way.first, let end = way.last else { continue }
//                let dStart = hypot(last.lat - first.lat, last.lon - first.lon)
//                let dEnd = hypot(last.lat - end.lat, last.lon - end.lon)
//                if dStart < bestDist { bestDist = dStart; bestIdx = i; bestReversed = false }
//                if dEnd < bestDist { bestDist = dEnd; bestIdx = i; bestReversed = true }
//            }
//            var next = remaining.remove(at: bestIdx)
//            if bestReversed { next.reverse() }
//            chain.append(contentsOf: next)
//        }
//        return chain
//    }
}
