//
//  LiveActivityManager.swift
//  Redline
//
//  Created by Riley Koo on 9/19/26.
//

import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<F1SessionAttributes>?

    // Throttling
    private var lastUpdateAt: Date = .distantPast
    private var lastPushedState: F1SessionAttributes.ContentState?
    private let minInterval: TimeInterval = 2.0   // don't push more than ~1 update / 2s

    // Coalescing: if updates arrive faster than minInterval, keep the *latest*
    // one and fire it once the window opens back up, instead of just dropping it.
    private var pendingState: F1SessionAttributes.ContentState?
    private var flushTask: Task<Void, Never>?

    private init() {}

    func start(sessionName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else { return } // already running, don't double-start

        let attrs = F1SessionAttributes(sessionName: sessionName)
        let initialState = F1SessionAttributes.ContentState(
            leaderTLA: "—", leaderGap: "", p2TLA: "—", p2Gap: "",
            p3TLA: "—", p3Gap: "", trackStatus: "", lapCount: ""
        )
        activity = try? Activity.request(
            attributes: attrs,
            content: .init(state: initialState, staleDate: nil)
        )
        lastUpdateAt = .distantPast
        lastPushedState = nil
        pendingState = nil
    }

    /// Call this as often as you want — it internally throttles/coalesces
    /// so the actual ActivityKit update calls stay well under Apple's budget.
    func update(from drivers: [Driver], trackStatus: String, lapCount: String) {
        guard activity != nil, drivers.count >= 3 else { return }

        let newState = F1SessionAttributes.ContentState(
            leaderTLA: drivers[0].tla, leaderGap: drivers[0].gap,
            p2TLA: drivers[1].tla, p2Gap: drivers[1].interval,
            p3TLA: drivers[2].tla, p3Gap: drivers[2].interval,
            trackStatus: trackStatus, lapCount: lapCount
        )

        // Skip entirely if nothing meaningful changed since the last push.
        if newState == lastPushedState { return }

        pendingState = newState

        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdateAt)
        if elapsed >= minInterval {
            flushPending()
        } else if flushTask == nil {
            // Schedule a flush for whenever the window opens, so the latest
            // pendingState still gets sent even if no further updates arrive.
            let wait = minInterval - elapsed
            flushTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                await self?.flushPending()
            }
        }
    }

    private func flushPending() {
        flushTask?.cancel()
        flushTask = nil
        guard let activity, let state = pendingState else { return }

        lastUpdateAt = Date()
        lastPushedState = state
        pendingState = nil

        // Mark stale after 90s of no updates — protects against showing
        // frozen data as if it were current if the app gets suspended.
        let staleDate = Date().addingTimeInterval(90)
        Task {
            await activity.update(.init(state: state, staleDate: staleDate))
        }
    }

    func end() {
        flushTask?.cancel()
        flushTask = nil
        pendingState = nil
        lastPushedState = nil
        let toEnd = activity
        activity = nil
        Task {
            await toEnd?.end(nil, dismissalPolicy: .immediate)
        }
    }
}
