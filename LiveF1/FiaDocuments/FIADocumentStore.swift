//
//  FIADocumentStore.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import Foundation
import Combine

// MARK: - Load State

enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)

    static func == (lhs: LoadState, rhs: LoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded): return true
        case (.failed(let a), .failed(let b)):                         return a == b
        default:                                                        return false
        }
    }
}

// MARK: - Store

@MainActor
final class FIADocumentStore: ObservableObject {

    // MARK: Published State

    @Published private(set) var documents: [FIADocument] = []
    @Published private(set) var loadState: LoadState = .idle
    @Published var searchText: String = ""
    @Published var selectedCategory: String = "All"

    // MARK: Derived

    var categories: [String] {
        let cats = Set(documents.map(\.category))
        return ["All"] + cats.sorted()
    }

    var filteredDocuments: [FIADocument] {
        documents.filter { doc in
            let matchesCategory = selectedCategory == "All" || doc.category == selectedCategory
            let matchesSearch   = searchText.isEmpty
                || doc.title.localizedCaseInsensitiveContains(searchText)
                || doc.category.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    var isLoading: Bool { loadState == .loading }

    // MARK: Private

    // FIADocumentFetcher is @MainActor so it lives here naturally
    private var fetcher: FIADocumentFetcher?
    private let cache = DocumentCache()
    private var fetchTask: Task<Void, Never>?

    // MARK: Public API

    func load(forceRefresh: Bool = false) {
        if fetchTask != nil && !forceRefresh {
            return
        }

        if forceRefresh {
            fetchTask?.cancel()
        }

        fetchTask = Task {
            await performLoad(forceRefresh: forceRefresh)
        }
    }

    func refresh() { load(forceRefresh: true) }

    // MARK: Private

    private func performLoad(forceRefresh: Bool) async {
        guard loadState != .loading else { return }
        loadState = .loading

        // Serve cache immediately, then silently refresh
        if !forceRefresh, let cached = cache.load(), !cached.isEmpty {
            documents = cached
            loadState = .loaded
            Task { await backgroundRefresh() }
            return
        }

        await fetchFromNetwork()
    }

    private func fetchFromNetwork() async {
        fetcher = FIADocumentFetcher()
        do {
            let fetched = try await fetcher!.fetchDocuments()
            guard !Task.isCancelled else {
                return
            }
            documents = fetched
            loadState = .loaded
            cache.save(fetched)
        } catch {
            guard !Task.isCancelled else { return }
            if let cached = cache.load(), !cached.isEmpty {
                documents = cached
                loadState = .failed("Showing cached results — \(error.localizedDescription)")
            } else {
                loadState = .failed(error.localizedDescription)
            }
        }
        fetcher = nil
    }

    private func backgroundRefresh() async {
        fetcher = FIADocumentFetcher()
        guard let fetched = try? await fetcher?.fetchDocuments(), !fetched.isEmpty else {
            fetcher = nil
            return
        }
        documents = fetched
        cache.save(fetched)
        fetcher = nil
    }
}

// MARK: - Document Cache

private struct DocumentCache {

    private let cacheURL: URL = {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FIADocuments.json")
    }()

    private let maxAge: TimeInterval = 3600 // 1 hour

    func save(_ documents: [FIADocument]) {
        let envelope = Envelope(savedAt: Date(), documents: documents)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    func load() -> [FIADocument]? {
        guard let data = try? Data(contentsOf: cacheURL),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              Date().timeIntervalSince(envelope.savedAt) < maxAge else { return nil }
        return envelope.documents
    }

    private struct Envelope: Codable {
        let savedAt: Date
        let documents: [FIADocument]
    }
}
