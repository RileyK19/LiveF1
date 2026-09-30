//
//  ExportMenu.swift
//  Redline
//
//  Created by Riley Koo on 9/25/26.
//

import SwiftUI

struct ExportMenu<Content: Exportable>: View {
    let source: Content
    @State private var shareURL: IdentifiableURL?
    @State private var isExporting = false
    @State private var showPermissionAlert = false

    var body: some View {
        Menu {
            Button("Save Image to Photos") {
                Task {
                    isExporting = true
                    defer { isExporting = false }
                    if let image = ChartExporter.image(from: source.exportContent, size: source.exportSize) {
                        try? await ChartExporter.saveToPhotos(image)
                    }
                }
            }
            Button("Export as PDF") {
                if let url = ChartExporter.pdf(from: source.exportContent, size: source.exportSize) {
                    shareURL = IdentifiableURL(url: url)
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .sheet(item: $shareURL) { wrapped in
            ShareSheet(activityItems: [wrapped.url])
        }
        .alert("Photo Access Needed", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow photo access in Settings to save exported charts.")
        }
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
