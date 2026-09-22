//
//  FIADocumentCardView.swift
//  Redline
//
//  Created by Riley Koo on 9/19/26.
//

import SwiftUI
import PDFKit

struct FIADocumentCardView: View {
    let documents: [FIADocumentInfo]
    let result: GetFIADocumentsResult

    @State private var selectedID: String?
    @State private var pdf: PDFDocument?
    @State private var loadFailed = false

    private let previewHeight: CGFloat = 320

    init(documents: [FIADocumentInfo], result: GetFIADocumentsResult) {
        self.documents = documents
        self.result = result
        // If the model read the document, open the newest one right away.
        _selectedID = State(initialValue: result.topDocumentText != nil ? documents.first?.id : nil)
    }

    private var selectedDocument: FIADocumentInfo? {
        documents.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if documents.isEmpty {
                Text(result.message ?? "No documents found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach(documents) { row($0) }
                }

                if result.totalMatches > documents.count {
                    Text("Showing \(documents.count) of \(result.totalMatches)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let doc = selectedDocument {
                    preview(for: doc)
                }
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity)
        .task(id: selectedID) { await loadPDF() }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("FIA Documents")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text("· as of \(result.asOf)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: Rows

    private func row(_ doc: FIADocumentInfo) -> some View {
        let isSelected = doc.id == selectedID

        return Button {
            withAnimation(.snappy) {
                selectedID = isSelected ? nil : doc.id
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(color(for: doc.status))
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.title)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Text(doc.status.rawValue)
                        if let date = doc.publishedAt {
                            Text("· \(date, style: .relative) ago")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "chevron.up" : "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.red.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func color(for status: FIADocumentInfo.Status) -> Color {
        switch status {
        case .investigation: return .orange
        case .decision:      return .red
        }
    }

    // MARK: Preview

    private func preview(for doc: FIADocumentInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let pdf {
                    FIAPDFPreview(document: pdf)
                } else if loadFailed {
                    Text("Couldn't load this PDF.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: previewHeight)
            .background(.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack {
                Link(destination: doc.pdfURL) {
                    Label("Open PDF", systemImage: "arrow.up.right.square")
                }
                Spacer()
                ShareLink(item: doc.pdfURL)
            }
            .font(.caption2)
            .foregroundStyle(.red)
        }
    }

    private func loadPDF() async {
        pdf = nil
        loadFailed = false
        guard let doc = selectedDocument else { return }

        do {
            let data = try await FIAPDFService.shared.data(for: doc)
            guard !Task.isCancelled else { return }
            if let loaded = PDFDocument(data: data) {
                pdf = loaded
            } else {
                loadFailed = true
            }
        } catch {
            if !Task.isCancelled { loadFailed = true }
        }
    }
}

// MARK: - PDFKit bridge (iOS)

struct FIAPDFPreview: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
        }
    }
}
