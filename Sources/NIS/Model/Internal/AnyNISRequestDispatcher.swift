//
//  AnyNISRequestDispatcher.swift
//  NIS
//
//  Created by Andrew Matsota on 29.04.2026.
//

import Foundation

/// Abstraction over request dispatching used for dependency injection.
///
/// Enables mocking request execution in tests and decouples consumers
/// (such as Combine bridges) from concrete dispatcher implementations.
protocol NISRequestDispatching: AnyObject {

    func request<T: Decodable>(
        _ request: URLRequest,
        as type: T.Type,
        decoder: JSONDecoder
    ) async -> NISResponse<T>
}
