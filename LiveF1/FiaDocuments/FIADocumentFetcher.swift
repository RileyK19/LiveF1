//
//  FIADocument.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import Foundation
import WebKit

// MARK: - Model

struct FIADocument: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let url: URL
    let category: String
    let publishedDate: Date?
    let relativeURLPath: String

    init(id: UUID = UUID(), title: String, url: URL, category: String,
         publishedDate: Date?, relativeURLPath: String) {
        self.id = id; self.title = title; self.url = url
        self.category = category; self.publishedDate = publishedDate
        self.relativeURLPath = relativeURLPath
    }
}

// MARK: - Errors

enum FIAFetchError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case noDocumentsFound
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid URL."
        case .networkError(let e):  return "Network error: \(e.localizedDescription)"
        case .noDocumentsFound:     return "No documents found."
        case .timeout:              return "Timed out waiting for the page to load."
        }
    }
}

// MARK: - Fetcher

@MainActor
final class FIADocumentFetcher: NSObject {

    // MARK: Config
    private var entryURL: URL {
        let year = Calendar.current.component(.year, from: Date())
        let seasonID = year + 46

        return URL(
            string: """
            https://www.fia.com/documents/championships/fia-formula-one-world-championship-14/season/season-\(year)-\(seasonID)
            """
        )!
    }
    var maxPages: Int       = 1
    private let pollInterval: TimeInterval = 1.0
    private let pageTimeout: TimeInterval  = 30

    // MARK: State
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<[FIADocument], Error>?
    private var pollTask: Task<Void, Never>?

    private var resolvedBaseURL: URL?   // the URL after the initial redirect
    private var currentPage       = 0
    private var allDocuments: [FIADocument] = []
    private var seenPaths         = Set<String>()
    private var pageDidFinishLoad = false
    private var lastExtractedCount = -1  // detect when a new page has different content

    // MARK: - Public

    func fetchDocuments() async throws -> [FIADocument] {
        try await withCheckedThrowingContinuation { cont in
            self.continuation      = cont
            self.allDocuments      = []
            self.seenPaths         = []
            self.currentPage       = 0
            self.resolvedBaseURL   = nil
            self.lastExtractedCount = -1
            self.setupWebView()
            // Step 1: load entry point — site will redirect to the current season URL
            self.loadURL(self.entryURL)
        }
    }

    // MARK: - WebView Setup

    private func setupWebView() {
        guard webView == nil else { return }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        wv.navigationDelegate = self
        wv.alpha = 0.01
        wv.isUserInteractionEnabled = false
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first?.windows.first {
            window.addSubview(wv)
        }
        self.webView = wv
    }

    private func teardown() {
        pollTask?.cancel(); pollTask = nil
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.removeFromSuperview()
        webView = nil
        pageDidFinishLoad = false
    }

    // MARK: - Loading

    private func loadURL(_ url: URL) {
        pageDidFinishLoad = false
        print("[FIA] Loading: \(url)")
        webView?.load(URLRequest(url: url))
        startPolling()
    }

    /// Build the URL for page N using the resolved base, e.g.:
    /// https://www.fia.com/documents/championships/.../season/season-2026-2072?page=1
    private func pageURL(for page: Int) -> URL? {
        guard let base = resolvedBaseURL else { return nil }
        guard page > 0 else { return base }
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "page", value: "\(page)")]
        return components?.url
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        let deadline = Date().addingTimeInterval(pageTimeout)

        pollTask = Task { [weak self] in
            guard let self else { return }
            while Date() < deadline {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }

                let count = await self.pdfLinkCount()
                print("[FIA] page=\(self.currentPage) didFinish=\(self.pageDidFinishLoad) pdfLinks=\(count)")

                guard self.pageDidFinishLoad, count > 0 else { continue }

                // For pages > 0, make sure content actually changed vs previous page
                // (site may return same page if page param is out of range)
                if self.currentPage > 0 && count == self.lastExtractedCount {
                    // Wait one more tick to be sure it's not just slow to change
                    try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                    let recheck = await self.pdfLinkCount()
                    if recheck == self.lastExtractedCount {
                        print("[FIA] Page \(self.currentPage) returned same content as previous — stopping pagination")
                        self.finish(with: self.sorted(self.allDocuments))
                        return
                    }
                }

                await self.extractAndAdvance()
                return
            }
            print("[FIA] Timeout on page \(self.currentPage)")
            if !self.allDocuments.isEmpty {
                self.finish(with: self.sorted(self.allDocuments))
            } else {
                self.finish(throwing: FIAFetchError.timeout)
            }
        }
    }

    private func pdfLinkCount() async -> Int {
        await withCheckedContinuation { cont in
            webView?.evaluateJavaScript(
                "Array.from(document.querySelectorAll('a[href]')).filter(a => a.href.toLowerCase().includes('.pdf')).length"
            ) { result, _ in
                cont.resume(returning: (result as? Int) ?? 0)
            }
        }
    }

    // MARK: - Extraction

    private let extractScript = """
    (function() {
        var docs = [];
        var seen = {};

        document.querySelectorAll('a[href]').forEach(function(a) {
            var href = (a.getAttribute('href') || '').trim();
            if (!href.toLowerCase().includes('.pdf')) return;
            if (seen[href]) return;
            seen[href] = true;

            var abs = href.startsWith('http')
                ? href
                : window.location.origin + (href.startsWith('/') ? '' : '/') + href;

            // Title
            var title = (a.getAttribute('aria-label') || '').trim();
            if (!title) title = (a.innerText || a.textContent || '').replace(/\\s+/g, ' ').trim();
            if (!title) {
                var container = a.closest('[class]');
                if (container) {
                    var h = container.querySelector('h1,h2,h3,h4,h5,.title,.document-title,span.name');
                    if (h) title = (h.innerText || '').trim();
                }
            }
            if (!title) {
                var parts = decodeURIComponent(href).split('/');
                title = parts[parts.length-1].replace(/\\.pdf$/i,'').replace(/[-_]/g,' ');
            }

            // Category + date — walk up ancestors
            var category = '', date = '';
            var node = a.parentElement;
            for (var i = 0; i < 8 && node; i++) {
                if (!category) {
                    var c = node.querySelector('.category,.document-category,.tag,[class*="category"],[class*="sport"],[class*="type"]');
                    if (c) { var t = (c.innerText||'').trim(); if (t) category = t; }
                }
                if (!date) {
                    var d = node.querySelector('time,[class*="date"],[class*="Date"],[datetime]');
                    if (d) date = (d.getAttribute('datetime') || d.innerText || '').trim();
                }
                node = node.parentElement;
            }

            docs.push({ title: title, href: abs, relative: href,
                        category: category || 'General', date: date });
        });

        return JSON.stringify({ count: docs.length, docs: docs });
    })();
    """

    private func extractAndAdvance() async {
        guard let wv = webView else { advanceOrFinish(newDocs: [], extractedCount: 0); return }

        return await withCheckedContinuation { cont in
            wv.evaluateJavaScript(self.extractScript) { [weak self] result, error in
                guard let self else { cont.resume(); return }

                guard error == nil,
                      let jsonStr = result as? String,
                      let data = jsonStr.data(using: .utf8),
                      let payload = try? JSONDecoder().decode(ExtractionResult.self, from: data) else {
                    print("[FIA] Extraction failed:", error?.localizedDescription ?? "decode error")
                    self.advanceOrFinish(newDocs: [], extractedCount: 0)
                    cont.resume()
                    return
                }

                print("[FIA] Extracted \(payload.count) docs from page \(self.currentPage)")
                let mapped = payload.docs.compactMap { self.map(raw: $0) }
                self.advanceOrFinish(newDocs: mapped, extractedCount: payload.count)
                cont.resume()
            }
        }
    }

    private struct ExtractionResult: Codable {
        let count: Int
        let docs: [RawDoc]
    }
    private struct RawDoc: Codable {
        let title: String; let href: String; let relative: String
        let category: String; let date: String
    }

    private func advanceOrFinish(newDocs: [FIADocument], extractedCount: Int) {
        lastExtractedCount = extractedCount

        var addedNew = false
        for doc in newDocs where !seenPaths.contains(doc.relativeURLPath) {
            seenPaths.insert(doc.relativeURLPath)
            allDocuments.append(doc)
            addedNew = true
        }

        currentPage += 1

        // Stop if we've hit max pages, got no new docs, or no resolved base to paginate from
        guard currentPage < maxPages, addedNew, let nextURL = pageURL(for: currentPage) else {
            finish(with: sorted(allDocuments))
            return
        }

        loadURL(nextURL)
    }

    // MARK: - Finish

    private func finish(with documents: [FIADocument]) {
        teardown()
        continuation?.resume(returning: documents)
        continuation = nil
    }

    private func finish(throwing error: Error) {
        teardown()
        continuation?.resume(throwing: error)
        continuation = nil
    }

    // MARK: - Helpers

    private func map(raw: RawDoc) -> FIADocument? {
        guard let url = URL(string: raw.href) else { return nil }
        let title = raw.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        return FIADocument(title: title, url: url,
                           category: raw.category.isEmpty ? "General" : raw.category,
                           publishedDate: parseDate(raw.date),
                           relativeURLPath: raw.relative)
    }

    private func parseDate(_ s: String) -> Date? {
        let fmts = ["dd.MM.yyyy","yyyy-MM-dd","dd/MM/yyyy","MMM dd, yyyy",
                    "yyyy-MM-dd'T'HH:mm:ssZ","dd MMM yyyy"]
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        for f in fmts { fmt.dateFormat = f; if let d = fmt.date(from: s.trimmingCharacters(in: .whitespacesAndNewlines)) { return d } }
        return nil
    }

    private func sorted(_ docs: [FIADocument]) -> [FIADocument] {
        docs.sorted {
            switch ($0.publishedDate, $1.publishedDate) {
            case let (l?, r?): return l > r
            default:           return $0.title < $1.title
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension FIADocumentFetcher: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageDidFinishLoad = true

        // Capture the resolved URL after any redirects (first page load only)
        if resolvedBaseURL == nil, let current = webView.url {
            // Strip any ?page= param to get the clean season base URL
            var components = URLComponents(url: current, resolvingAgainstBaseURL: false)
            components?.queryItems = nil
            resolvedBaseURL = components?.url ?? current
            print("[FIA] Resolved base URL: \(resolvedBaseURL!)")
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        finish(throwing: FIAFetchError.networkError(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        finish(throwing: FIAFetchError.networkError(error))
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(navigationResponse.response.mimeType == "application/pdf" ? .cancel : .allow)
    }
}
