//
//  GetFIADocumentsTool.swift
//  Redline
//
//  Created by Riley Koo on 9/19/26.
//

import Foundation
import FoundationModels
import PDFKit
import CryptoKit

// MARK: - Lightweight document model
//
// The ONLY place that touches FIADocument's fields is `init?(_ doc:)` below.

struct FIADocumentInfo: Identifiable, Equatable, Sendable {
    enum Status: String, Sendable {
        case investigation = "Under investigation"
        case decision = "Decision"
    }

    let id: String
    let title: String
    let pdfURL: URL
    let publishedAt: Date?
    let docNumber: Int?
    let carNumbers: [Int]
    let status: Status
}

extension FIADocumentInfo {

    // Tune these against real titles. Matching is case-insensitive.
    private static let excluded = [
        "classification", "timing", "lap chart", "history chart", "lap analysis",
        "starting grid", "results", "speed trap", "pit stop"
    ]
    private static let investigationWords = ["summons", "investigation", "noted", "under review"]
    private static let decisionWords = [
        "penalty", "infringement", "decision", "offence", "reprimand",
        "disqualif", "no further action", "drive through", "stop and go"
    ]

    /// Returns nil for documents the tool shouldn't surface (no URL, timing sheets, etc.).
    init?(_ doc: FIADocument) {
        let pdfURL = doc.url
        let published = doc.publishedDate
        let id = doc.id.uuidString
        let title = doc.title
        let category = doc.category

        let lowerTitle = title.lowercased()
        let haystack = lowerTitle + " " + category.lowercased()

        guard !Self.excluded.contains(where: { lowerTitle.contains($0) }) else { return nil }

        let isInvestigation = Self.investigationWords.contains { haystack.contains($0) }
        let isDecision = Self.decisionWords.contains { haystack.contains($0) }
        guard isInvestigation || isDecision else { return nil }

        self.id = id
        self.title = title
        self.pdfURL = pdfURL
        self.publishedAt = published
        self.docNumber = Self.firstCapture(#"\bdoc(?:ument)?\.?\s*(\d+)"#, in: title).flatMap { Int($0) }
        self.carNumbers = Self.carNumbers(in: title)
        self.status = isInvestigation ? .investigation : .decision
    }

    static func relevant(from documents: [FIADocument]) -> [FIADocumentInfo] {
        documents.compactMap { FIADocumentInfo($0) }
    }

    // MARK: Title parsing

    /// "Car 44", "Cars 4 & 44", "Car #16" → [44], [4, 44], [16]
    private static func carNumbers(in title: String) -> [Int] {
        let pattern = #"\bcars?\b\s*#?\s*((?:\d{1,2}(?:\s*(?:,|&|/|and)\s*#?)?)+)"#
        return allCaptures(pattern, in: title)
            .flatMap { $0.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) } }
    }

    private static func allCaptures(_ pattern: String, in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return re.matches(in: text, range: range).compactMap { m in
            guard m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        allCaptures(pattern, in: text).first
    }
}

// MARK: - PDF download + text extraction (off the main actor)

enum FIAPDFError: LocalizedError {
    case badResponse
    case unreadable

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Couldn't download the document."
        case .unreadable:  return "Couldn't read text from the document."
        }
    }
}

actor FIAPDFService {
    static let shared = FIAPDFService()

    private let directory: URL

    init() {
        directory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FIAPDFs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Raw PDF bytes, cached on disk. Used by both the tool (text) and the card (preview).
    func data(for doc: FIADocumentInfo) async throws -> Data {
        let file = directory.appendingPathComponent(cacheKey(for: doc.pdfURL) + ".pdf")

        if let cached = try? Data(contentsOf: file), PDFDocument(data: cached) != nil {
            return cached
        }

        let (data, response) = try await URLSession.shared.data(from: doc.pdfURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              PDFDocument(data: data) != nil else {
            throw FIAPDFError.badResponse
        }
        try? data.write(to: file, options: .atomic)
        return data
    }

    /// Whitespace-collapsed text, truncated to keep the model's context small.
    func text(for doc: FIADocumentInfo, maxCharacters: Int) async throws -> String {
        let data = try await data(for: doc)
        guard let pdf = PDFDocument(data: data), let raw = pdf.string else {
            throw FIAPDFError.unreadable
        }
        let collapsed = raw.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !collapsed.isEmpty else { throw FIAPDFError.unreadable }
        return collapsed.count > maxCharacters
            ? String(collapsed.prefix(maxCharacters)) + "…"
            : collapsed
    }

    // Stable across launches (unlike hashValue).
    private func cacheKey(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Driver directory (independent of any loaded race)

/// Driver lineup for name matching. Fetched once from the newest race session that has drivers
/// and cached for the app's lifetime. Never touches CurrentSessionStore or loads a race.
@MainActor
enum FIADriverDirectory {
    private static var cached: [(number: Int, fullName: String)] = []

    static func candidates() async -> [(number: Int, fullName: String)] {
        if !cached.isEmpty { return cached }

        let year = Calendar.current.component(.year, from: Date())
        guard let sessions = try? await F1PredictorSessionParser.fetchRaces(year: year, sessionType: "Race") else {
            return []
        }

        // Assumes chronological order. A future session has no drivers yet, so walk back until one does.
        for session in sessions.reversed().prefix(3) {
            let info = (try? await F1PredictorDriverParser.fetch(sessionKey: "\(session.sessionKey)")) ?? []
            if !info.isEmpty {
                cached = info.map { (number: $0.driverNumber, fullName: $0.fullName) }
                return cached
            }
        }
        return []
    }
}

// MARK: - Tool types

@Generable
struct GetFIADocumentsArguments {
    @Guide(description: "Driver names exactly as the user wrote them, e.g. [\"Max\", \"Hamilton\"]. Leave empty to include every driver. Don't correct spelling or guess numbers.")
    var driverNames: [String]

    @Guide(description: "True to also read the text of the newest matching document, for questions like 'why was Hamilton penalized?' or 'what happened with Norris?'. False to only list matching documents, for questions like 'any penalties?' or 'what's under investigation?'.")
    var readDetails: Bool
}

@Generable
struct FIADocumentMatch: Sendable {
    var title: String
    var status: String
    var published: String?
}

@Generable
struct GetFIADocumentsResult: Sendable {
    var success: Bool
    var message: String?
    @Guide(description: "The drivers the requested names were matched to. Always name them in your answer so the user can catch a wrong match.")
    var resolvedDrivers: String?
    var asOf: String
    var totalMatches: Int
    @Guide(description: "Newest first.")
    var matches: [FIADocumentMatch]
    @Guide(description: "Text of the first (newest) match. Only present when readDetails was true.")
    var topDocumentText: String?
}

// MARK: - Tool

@MainActor
struct GetFIADocumentsTool: Tool {
    let name = "getFIADocuments"
    let description = "Lists FIA stewards' documents (penalties, decisions, investigations) for the current race weekend, optionally for specific drivers by name. Set readDetails to true to also get the text of the newest match. No documents found does NOT prove there is no penalty — it may not be published yet."

    let store: FIADocumentStore
    let onResult: @Sendable ([FIADocumentInfo], GetFIADocumentsResult) -> Void

    private static let maxMatches = 5
    private static let maxCharacters = 1800   // ≈ 450 tokens; tune against your context budget

    func call(arguments: GetFIADocumentsArguments) async throws -> GetFIADocumentsResult {
        await ensureDocumentsLoaded()
        let asOf = Date().formatted(date: .omitted, time: .shortened)

        guard !store.documents.isEmpty else {
            return finish(docs: [], empty(
                success: false,
                message: "FIA documents couldn't be loaded right now. Tell the user; don't guess.",
                asOf: asOf
            ))
        }

        // MARK: Resolve names → car numbers

        let queries = arguments.driverNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var wanted = Set<Int>()
        var resolvedLabel: String?

        if !queries.isEmpty {
            let candidates = await FIADriverDirectory.candidates()
            var labels: [String] = []

            for query in queries {
                guard let number = NameMatcher.bestGuess(for: query, in: candidates) else { continue }
                wanted.insert(number)
                let fullName = candidates.first { $0.number == number }?.fullName ?? "Car \(number)"
                labels.append("\(fullName) (#\(number))")
            }

            // An empty `wanted` means "all drivers", so unresolved names must never fall through to it.
            guard !wanted.isEmpty else {
                return finish(docs: [], empty(
                    success: false,
                    message: "Couldn't look up those driver names right now. Tell the user, or offer to check the whole session instead.",
                    asOf: asOf
                ))
            }
            resolvedLabel = labels.joined(separator: ", ")
        }

        // MARK: Filter + sort

        let relevant = FIADocumentInfo.relevant(from: store.documents).sorted {
            ($0.publishedAt ?? .distantPast, $0.docNumber ?? 0) >
            ($1.publishedAt ?? .distantPast, $1.docNumber ?? 0)
        }

        let filtered = wanted.isEmpty
            ? relevant
            : relevant.filter { !wanted.isDisjoint(with: $0.carNumbers) }

        guard !filtered.isEmpty else {
            let scope = resolvedLabel ?? "this session"
            return finish(docs: [], empty(
                success: true,
                message: "No penalty or investigation documents found for \(scope) as of \(asOf). This does not confirm there is no penalty — it may not be published yet.",
                asOf: asOf,
                resolved: resolvedLabel
            ))
        }

        let shown = Array(filtered.prefix(Self.maxMatches))

        // MARK: Optionally read the newest document

        var text: String?
        var message: String?
        if arguments.readDetails, let top = shown.first {
            text = try? await FIAPDFService.shared.text(for: top, maxCharacters: Self.maxCharacters)
            if text == nil {
                message = "Couldn't read the PDF text; only titles are available."
            }
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let matches = shown.map { doc in
            FIADocumentMatch(
                title: doc.title,
                status: doc.status.rawValue,
                published: doc.publishedAt.map { formatter.localizedString(for: $0, relativeTo: Date()) }
            )
        }

        return finish(docs: shown, GetFIADocumentsResult(
            success: true,
            message: message,
            resolvedDrivers: resolvedLabel,
            asOf: asOf,
            totalMatches: filtered.count,
            matches: matches,
            topDocumentText: text
        ))
    }

    // MARK: Helpers

    private func empty(success: Bool, message: String, asOf: String, resolved: String? = nil) -> GetFIADocumentsResult {
        GetFIADocumentsResult(
            success: success,
            message: message,
            resolvedDrivers: resolved,
            asOf: asOf,
            totalMatches: 0,
            matches: [],
            topDocumentText: nil
        )
    }

    private func finish(docs: [FIADocumentInfo], _ result: GetFIADocumentsResult) -> GetFIADocumentsResult {
        onResult(docs, result)
        return result
    }

    /// Kicks off a load if needed and waits (up to ~10s) for documents to arrive.
    private func ensureDocumentsLoaded() async {
        guard store.documents.isEmpty else { return }

        if case .failed = store.loadState { store.refresh() } else { store.load() }
        try? await Task.sleep(for: .milliseconds(50))   // let the load task start

        var ticks = 0
        while store.documents.isEmpty, ticks < 100 {
            if case .failed = store.loadState { break }
            if store.loadState == .loaded { break }
            try? await Task.sleep(for: .milliseconds(100))
            ticks += 1
        }
    }
}
