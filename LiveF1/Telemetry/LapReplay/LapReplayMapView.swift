//
//  LapReplayMapView.swift
//  Redline
//
//  Created by Riley Koo on 8/31/26.
//


import CoreLocation
import MapKit
import SwiftUI

struct LapReplayMapView: UIViewRepresentable {
    @ObservedObject var viewModel: LapReplayViewModel
    var isZoomed: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.mapType = .standard
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator

        // Overlays and annotations are only added once per load (keyed by trace id set) --
        // re-adding them every playback tick would be needlessly expensive. Live movement is
        // handled separately by mutating each DriverDotAnnotation's coordinate in place,
        // which the view model already does every tick (see syncDotAnnotations()).
        let traceIDs = Set(viewModel.traces.map(\.id))
        if coordinator.renderedTraceIDs != traceIDs {
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations)
            mapView.addOverlays(viewModel.coloredPolylines)
            mapView.addAnnotations(viewModel.dotAnnotations)
            coordinator.renderedTraceIDs = traceIDs
        }

        // Camera: fit the whole track when not zoomed; follow the live dot(s) when zoomed.
        let targetRegion: MKCoordinateRegion?
        if isZoomed {
            let liveCoordinates = viewModel.liveReadouts().map(\.coordinate)
            targetRegion = Self.regionFollowing(liveCoordinates) ?? viewModel.fullTrackRegion
        } else {
            targetRegion = viewModel.fullTrackRegion
        }

        if let targetRegion, coordinator.shouldUpdateCamera(to: targetRegion, zoomed: isZoomed) {
            mapView.setRegion(targetRegion, animated: !coordinator.isFirstRegion)
            coordinator.isFirstRegion = false
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// A tight region around the live dot(s), used while zoomed so the camera follows the car.
    private static func regionFollowing(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let minSpan = 0.0025 // floor so a single car doesn't zoom in to nothing, ~250m
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 3.5, minSpan),
            longitudeDelta: max((maxLon - minLon) * 3.5, minSpan)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var renderedTraceIDs: Set<String> = []
        var isFirstRegion = true
        private var lastAppliedZoomedState: Bool?
        private var lastRegionCenter: CLLocationCoordinate2D?

        /// Avoids fighting the user's own pan/zoom gestures: recenter automatically on the
        /// first render, whenever the zoom-toggle state changes, and (while zoomed) whenever
        /// the live point drifts meaningfully -- but not on every single tick if it hasn't.
        func shouldUpdateCamera(to region: MKCoordinateRegion, zoomed: Bool) -> Bool {
            defer {
                lastAppliedZoomedState = zoomed
                lastRegionCenter = region.center
            }
            if isFirstRegion { return true }
            if lastAppliedZoomedState != zoomed { return true }
            guard zoomed, let last = lastRegionCenter else { return !zoomed && lastRegionCenter == nil }
            let moved = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: region.center.latitude, longitude: region.center.longitude))
            return moved > 2 // meters
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let colored = overlay as? ColoredPolyline {
                let renderer = MKPolylineRenderer(polyline: colored)
                renderer.strokeColor = colored.color
                renderer.lineWidth = 3
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let dot = annotation as? DriverDotAnnotation else { return nil }
            let identifier = "DriverDot"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: dot, reuseIdentifier: identifier)
            view.annotation = dot
            view.markerTintColor = dot.color
            view.glyphText = dot.driverID.components(separatedBy: " ").first?.replacingOccurrences(of: "#", with: "")
            view.displayPriority = .required
            view.canShowCallout = true
            return view
        }
    }
}
