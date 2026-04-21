//
//  NISPublisher.swift
//  NIS
//
//  Created by Andrew Matsota on 21.04.2026.
//

import Combine
import Foundation

/// Internal Combine bridge for `NISRequestDispatcher`.
///
/// Converts async request execution into a Combine publisher.
///
/// ## Behavior
/// - Emits exactly one `NISResponse<T>`
/// - Completes immediately after emission
/// - Ignores demand (single-shot publisher)
///
/// ## Cancellation
/// - Cancelling subscription cancels underlying async `Task`
/// - No values are delivered after cancellation
///
/// ## Concurrency
/// - Avoids capturing `self` inside `Task`
/// - Uses `NISUncheckedSendableBox` to safely bridge subscriber
internal struct NISPublisher<T: Decodable>: Publisher {

    typealias Output = NISResponse<T>
    typealias Failure = Never

    private let dispatcher: NISRequestDispatcher
    private let request: URLRequest
    private let decoder: JSONDecoder

    init(
        dispatcher: NISRequestDispatcher,
        request: URLRequest,
        decoder: JSONDecoder
    ) {
        self.dispatcher = dispatcher
        self.request = request
        self.decoder = decoder
    }

    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        let subscription = Subscription(
            subscriber: subscriber,
            dispatcher: dispatcher,
            request: request,
            decoder: decoder,
            type: T.self
        )

        subscriber.receive(subscription: subscription)
    }
}

// MARK: - Subscription

private extension NISPublisher {

    /// Internal mutable state holder.
    ///
    /// Exists to:
    /// - avoid capturing `self` inside Task
    /// - safely coordinate cancellation and delivery
    final class State<S>: @unchecked Sendable {
        var subscriber: S?
        var isCancelled = false
    }

    final class Subscription<S: Subscriber>: Combine.Subscription where S.Input == Output {
        private var task: Task<Void, Never>?
        private let state: State<S>

        private let dispatcher: NISRequestDispatcher
        private let request: URLRequest
        private let decoder: JSONDecoder
        private let type: T.Type

        // MARK: - Init

        init(
            subscriber: S,
            dispatcher: NISRequestDispatcher,
            request: URLRequest,
            decoder: JSONDecoder,
            type: T.Type
        ) {
            let state = State<S>()
            state.subscriber = subscriber

            self.state = state
            self.dispatcher = dispatcher
            self.request = request
            self.decoder = decoder
            self.type = type
        }

        // MARK: - Combine.Subscription

        /// Starts async request execution.
        ///
        /// Demand is ignored because publisher emits only one value.
        func request(_ demand: Subscribers.Demand) {
            guard task == nil else { return }
            let state = self.state
            task = Task { [dispatcher, request, decoder, type] in
                let response = await dispatcher.request(
                    request,
                    as: type,
                    decoder: decoder
                )

                // Do not deliver after cancellation
                guard !Task.isCancelled else { return }
                guard !state.isCancelled else { return }

                // Ensure subscriber still exists
                guard state.subscriber != nil else { return }

                _ = state.subscriber?.receive(response)
                state.subscriber?.receive(completion: .finished)

                // Release after completion
                state.subscriber = nil
            }
        }

        /// Cancels underlying async task and prevents further delivery.
        func cancel() {
            state.isCancelled = true
            state.subscriber = nil

            task?.cancel()
            task = nil
        }
    }
}
