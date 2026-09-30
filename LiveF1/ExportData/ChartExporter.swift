//
//  ChartExporter.swift
//  Redline
//
//  Created by Riley Koo on 9/25/26.
//


// ChartExporter.swift
import SwiftUI
import Photos

@MainActor
enum ChartExporter {
    static func image(from view: some View, size: CGSize, scale: CGFloat = 3) -> UIImage? {
        let hosted = hostedView(for: view, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            hosted.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }

    static func pdf(from view: some View, size: CGSize) -> URL? {
        let hosted = hostedView(for: view, size: size)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size))

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = documentsURL.appendingPathComponent("RacePace-Baku.pdf") // pass filename in properly

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                hosted.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            }
            return url
        } catch {
            print("PDF export failed: \(error)")
            return nil
        }
    }
    
    @MainActor
    private static func hostedView(for view: some View, size: CGSize) -> UIView {
        let controller = UIHostingController(rootView: view.frame(width: size.width, height: size.height).background(.white))
        controller.view.frame = CGRect(origin: .zero, size: size)

        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()

        return controller.view
    }

    static func saveToPhotos(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        switch status {
        case .authorized, .limited:
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        case .denied, .restricted:
            throw ExportError.photoAccessDenied
        case .notDetermined:
            throw ExportError.photoAccessDenied // shouldn't happen post-request, but be safe
        @unknown default:
            throw ExportError.photoAccessDenied
        }
    }

    enum ExportError: LocalizedError {
        case photoAccessDenied
        var errorDescription: String? { "Photo library access was denied." }
    }
}
