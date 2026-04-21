//
//  InflightRequestStore.swift
//  NIS
//
//  Created by Andrew Matsota on 14.04.2026.
//

import Foundation

/// Actor responsible for coordinating request execution reuse.
///
/// `InflightRequestStore` provides two core capabilities:
///
/// 1. **In-flight deduplication**
///    - Multiple identical requests share a single running task
///
/// 2. **Short-lived completed response reuse (TTL-based)**
///    - Recently completed results may be reused according to policy
///
/// ## Design goals
/// - eliminate duplicate concurrent work
/// - reduce redundant rapid re-requests (e.g. SwiftUI `.task`)
/// - keep implementation lightweight (NOT a full cache)
///
/// ## Guarantees
/// - thread-safe via actor isolation
/// - deterministic behavior per request key
/// - bounded memory via TTL expiration
///
/// ## Important
/// - This is NOT a persistent cache
/// - Responses are reused only within short TTL windows
/// - Use carefully for non-critical data (avoid auth / financial flows)
internal actor InflightRequestStore {

    // MARK: - Types

    typealias Payload = Result<NISResponseData, NISError>
    private typealias TaskType = Task<Payload, Never>

    /// Resolution describing how a request was fulfilled.
    ///
    /// ## Semantics
    /// - `.inflight` → joined existing running task
    /// - `.cache` → reused recently completed result
    /// - `.new` → executed new network request
    struct Resolution: Sendable {

        /// Origin of the result
        enum Source: Sendable {
            case inflight
            case cache
            case new
        }

        /// Final request result
        let result: Payload

        /// Indicates whether response was reused
        ///
        /// `true` for:
        /// - in-flight join
        /// - cache reuse
        ///
        /// `false` for:
        /// - fresh execution
        let isDuplicate: Bool

        /// Source of the result
        let source: Source
    }

    /// Cached completed response entry.
    private struct CacheEntry: Sendable {
        let payload: Payload
        let expiry: Date

        /// Indicates whether cache entry is still valid.
        var isValid: Bool {
            expiry > Date()
        }
    }

    /// Internal entry for in-flight tracking with subscriber count.
    private struct Entry {
        let task: TaskType
        var subscribers: Int
    }

    // MARK: - Storage

    private var tasks: [Int: Entry] = [:]
    private var cache: [Int: CacheEntry] = [:]

    // MARK: - Public API

    /// Resolves a request using deduplication and optional reuse.
    ///
    /// ## Execution flow
    /// 1. If a task is already running → join it
    /// 2. Else if valid cached result exists → return cached
    /// 3. Else → execute new operation
    ///
    /// - Parameters:
    ///   - key: Stable request identity hash
    ///   - policy: Reuse policy controlling cache behavior
    ///   - operation: Async operation producing request result
    ///
    /// - Returns:
    ///   Resolution describing the result and its origin
    func value(
        for key: Int,
        policy: NISRecentResponseReusePolicy,
        operation: @escaping @Sendable () async -> Payload
    ) async -> Resolution {
        cleanup(key)

        // 1. In-flight deduplication
        if var entry = tasks[key] {
            entry.subscribers += 1
            tasks[key] = entry

            return await waitForTask(
                entry.task,
                key: key,
                isDuplicate: true,
                source: .inflight
            )
        }

        // 2. Cache reuse
        if policy.isEnabled, let cached = cache[key], cached.isValid {
            return Resolution(
                result: cached.payload,
                isDuplicate: true,
                source: .cache
            )
        }

        // 3. Execute new request
        let task = Task { await operation() }
        tasks[key] = Entry(task: task, subscribers: 1)

        // ensures cleanup even if flow changes
        defer { tasks[key] = nil }

        let resolution = await waitForTask(
            task,
            key: key,
            isDuplicate: false,
            source: .new
        )

        storeIfNeeded(resolution.result, key: key, policy: policy)

        return resolution
    }
}

// MARK: - Private Helpers

private extension InflightRequestStore {

    /// Waits for task with per-subscriber cancellation handling.
    private func waitForTask(
        _ task: TaskType,
        key: Int,
        isDuplicate: Bool,
        source: Resolution.Source
    ) async -> Resolution {
        await withTaskCancellationHandler(
            operation: {
                let result = await task.value
                return Resolution(
                    result: result,
                    isDuplicate: isDuplicate,
                    source: source
                )
            },
            onCancel: {
                Task {
                    await self.handleCancellation(for: key)
                }
            }
        )
    }

    /// Handles subscriber cancellation.
    ///
    /// Decrements subscriber count and cancels underlying task if no subscribers remain.
    func handleCancellation(for key: Int) {
        guard var entry = tasks[key] else { return }

        entry.subscribers -= 1

        if entry.subscribers <= 0 {
            entry.task.cancel()
            tasks[key] = nil
        } else {
            tasks[key] = entry
        }
    }

    /// Removes expired cache entries for a given key.
    func cleanup(_ key: Int) {
        if let cached = cache[key], !cached.isValid {
            cache[key] = nil
        }
    }

    /// Stores result in cache if allowed by policy.
    func storeIfNeeded(
        _ result: Payload,
        key: Int,
        policy: NISRecentResponseReusePolicy
    ) {
        guard let ttl = policy.ttl else { return }
        
        switch result {
        case .success where policy.allowsSuccess:
            break
        case .failure where policy.allowsFailure:
            break
        default:
            return
        }

        cache[key] = CacheEntry(
            payload: result,
            expiry: Date().addingTimeInterval(ttl)
        )
    }
}
