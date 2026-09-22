//
//  SessionSelectionCoordinator.swift
//  Redline
//
//  Created by Riley Koo on 9/5/26.
//

import Foundation
import FoundationModels
import Combine

@Generable
struct SessionOption: Sendable, Equatable, Hashable {
    var raceName: String
    var round: String
    var sessionName: String   // "Race", "Sprint", "Qualifying", "FP1", etc.
    var formattedDateTime: String
}

@MainActor
final class SessionSelectionCoordinator: ObservableObject {
    /// Non-nil while a tool call is waiting on the user to pick one of these.
    @Published var currentOptions: [SessionOption]? = nil

    private var continuation: CheckedContinuation<SessionOption, Error>?

    func requestSelection(options: [SessionOption]) async throws -> SessionOption {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.currentOptions = options
        }
    }

    func resolve(with option: SessionOption) {
        continuation?.resume(returning: option)
        continuation = nil
        currentOptions = nil
    }

    func cancel() {
        continuation?.resume(throwing: CancellationError())
        continuation = nil
        currentOptions = nil
    }
}
