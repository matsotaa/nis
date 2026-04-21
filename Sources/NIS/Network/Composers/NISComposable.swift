//
//  AnyNISComposer.swift
//  NIS
//
//  Created by Andrew Matsota on 09.04.2026.
//

/// A protocol describing an ordered, immutable composition of homogeneous elements.
///
/// `NISComposable` is a core building block used across the networking SDK to construct
/// deterministic execution pipelines (e.g. adapters, interceptors, retriers).
///
/// ## Responsibilities
/// - Maintains **ordered execution**
/// - Ensures **immutability** (all mutations produce a new instance)
/// - Supports **composition flattening** to avoid nested pipelines
///
/// ## Design Guarantees
/// - The order of `stack` strictly defines execution order
/// - `appending` operations never mutate the original instance
/// - Nested composers are flattened when compatible, ensuring optimal traversal
///
/// ## Scope
/// This protocol is intentionally limited to **composition mechanics only**.
/// Execution semantics (how elements are invoked) are defined by conforming types.
///
/// ## Thread Safety
/// Value semantics are expected. Implementations should avoid shared mutable state.
///
/// - Important:
/// Implementations must be lightweight. Composition happens frequently and should not
/// introduce noticeable overhead.
public protocol NISComposable {
    
    /// The type of elements stored in the composition.
    associatedtype Item
    
    /// Ordered collection representing the execution pipeline.
    ///
    /// Elements are executed strictly in the order they appear.
    var stack: [Item] { get }
    
    /// Initializes a composer with a pre-built ordered stack.
    ///
    /// - Parameter stack: Elements arranged in execution order.
    ///
    /// - Important:
    /// The provided stack is expected to already respect ordering guarantees.
    init(_ stack: [Item])
}

public extension NISComposable {
    
    /// Appends a single element to the composition.
    ///
    /// - Parameter next: Element to append.
    /// - Returns: A new composer instance with the element appended.
    ///
    /// ## Behavior
    /// - Preserves existing order
    /// - Flattens nested composers when applicable
    ///
    /// ## Complexity
    /// Linear relative to the number of appended elements.
    func appending(_ next: Item) -> Self {
        appending(contentsOf: [next])
    }
    
    /// Appends multiple elements to the composition.
    ///
    /// - Parameter contentsOf: Elements to append in order.
    /// - Returns: A new composer instance with appended elements.
    ///
    /// ## Flattening
    /// If any appended element is itself a compatible composer, its internal
    /// stack will be extracted and merged directly into the resulting pipeline.
    ///
    /// This avoids nested composition structures and ensures optimal iteration.
    func appending(contentsOf nexts: [Item]) -> Self {
        Self(stack + nexts.flatMap(Self.flattenedItems(from:)))
    }
    
    /// Convenience initializer for variadic composition.
    ///
    /// - Parameter stack: Elements to compose in execution order.
    ///
    /// ## Example
    /// ```swift
    /// let composer = AdapterComposer(AuthAdapter(), LocaleAdapter())
    /// ```
    init(_ stack: Item...) {
        self.init(stack)
    }
    
    /// Extracts flattened items from a potentially nested composer.
    ///
    /// - Parameter item: Element that may represent a nested composer.
    /// - Returns: Flattened array of elements.
    ///
    /// ## Behavior
    /// - If `item` is not a composer → returned as-is
    /// - If `item` is a composer of compatible type → its stack is extracted
    /// - If types mismatch → fallback to treating as a single element
    ///
    /// ## Rationale
    /// Ensures that composition trees remain flat, improving:
    /// - iteration performance
    /// - predictability of execution order
    private static func flattenedItems(from item: Item) -> [Item] {
        guard let composer = item as? any NISComposable else { return [item] }
        let items = composer.stack.compactMap { $0 as? Item }
        return items.isEmpty ? [item] : items
    }
}
