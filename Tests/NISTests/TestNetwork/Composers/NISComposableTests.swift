//
//  NISComposableTests.swift
//  NIS
//
//  Created by Andrew Matsota on 01.05.2026.
//

import XCTest

@testable import NIS

/// Unit tests for protocol `NISComposable`'s extension methods
final class NISComposableTests: XCTestCase {
    
    // MARK: - Test Methods
    
    func testAppendingBuildsPipelineAndDoesNotMutateOriginal() {
        // GIVEN
        let extraComposer = Composer([Item.d])
        let originalComposer = Composer([Item.a])
        var composer = originalComposer.appending(contentsOf: [])

        // WHEN
        XCTAssertEqual(id(extraComposer), "composer.d")
        XCTAssertEqual(id(originalComposer), "composer.a")
        XCTAssertEqual(id(composer), "composer.a")
        composer = composer.appending(contentsOf: [Item.b])

        // THEN
        XCTAssertEqual(id(originalComposer), "composer.a")
        XCTAssertEqual(id(composer), "composer.a.b")

        // WHEN
        composer = composer.appending(Item.c)
        
        // THEN
        XCTAssertEqual(id(originalComposer), "composer.a")
        XCTAssertEqual(id(composer), "composer.a.b.c")

        // WHEN
        composer = composer.appending(extraComposer)

        // THEN
        XCTAssertEqual(id(originalComposer), "composer.a")
        XCTAssertEqual(id(composer), "composer.a.b.c.d")
    }
    
    func testVariadicInitializer() {
        // GIVEN
        var composer = Composer(Item.a, Item.b)
        
        // THEN
        XCTAssertEqual(id(composer), "composer.a.b")
        
        // WHEN
        composer = Composer(Item.a, Item.b, Item.c)
        
        // THEN
        XCTAssertEqual(id(composer), "composer.a.b.c")
    }
}

// MARK: - Private Helpers

private extension NISComposableTests {
    
    protocol ItemProtocol: Equatable {
        var id: String { get }
    }
    
    struct Composer: NISComposable, ItemProtocol {
        static func == (lhs: NISComposableTests.Composer, rhs: NISComposableTests.Composer) -> Bool {
            lhs.id == rhs.id
        }
        
        var id: String { (["composer"] + stack.map(\.id)).joined(separator: ".") }
        
        var stack: [any ItemProtocol]
        
        init(_ stack: [any ItemProtocol]) {
            self.stack = stack
        }
    }
    
    enum Item: String, ItemProtocol {
        var id: String { rawValue }
        case a, b, c, d
    }
    
    func id(_ items: any ItemProtocol...) -> String {
        items.map(\.id).joined(separator: ".")
    }
}

/*
 func appending(_ next: Item) -> Self {
     appending(contentsOf: [next])
 }
 
 func appending(contentsOf nexts: [Item]) -> Self {
     Self(stack + nexts.flatMap(Self.flattenedItems(from:)))
 }

 init(_ stack: Item...) {
     self.init(stack)
 }

 private static func flattenedItems(from item: Item) -> [Item] {
     guard let composer = item as? any NISComposable else { return [item] }
     let items = composer.stack.compactMap { $0 as? Item }
     return items.isEmpty ? [item] : items
 }
 */
