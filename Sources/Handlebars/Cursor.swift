//
//  Cursor.swift
//  Handlebars
//
//  Created by Jason Jobe on 8/25/25.
//


//
//  Cursor.swift
//  Foundry
//
//  Created by Jason Jobe on 8/23/25.
//
import Foundation


public struct Cursor<Input: Collection> {
    public typealias Element = Input.Element
    public typealias SubSequence = Input.SubSequence
    
    let input: Input
    public var index: Int
    public var count: Int { input.count }
    public var isAtEnd: Bool { index >= count }
    public var hasInput: Bool { index < count }
    public var rest: SubSequence { input[_index...] }
    
    var _index: Input.Index {
        input.index(input.startIndex, offsetBy: index)
    }
    /// Creates a new scanner over the provided input.
    /// - Parameter input: The string or substring to scan.
    public init(_ input: Input) {
        self.input = input
        self.index = 0
    }
    
    mutating public func jump(by cnt: Int) {
        index += cnt
        if index < 0 { index = 0 }
        if index >= count { index = count }
    }
    
    mutating public func next() -> Element? {
        defer { index += 1 }
        return currentElement
    }
    
    public var currentElement: Element? {
        return _index < input.endIndex ? input[_index] : nil
    }
}

public extension Cursor {
    mutating
    func scan(until cond: (Element) -> Bool) -> SubSequence {
        let head = _index
        while hasInput, let el = currentElement, !cond(el) {
            index += 1
        }
        return input[head..<_index]
    }
    
    mutating
    func scan(while cond: (Element) -> Bool) -> SubSequence {
        let head = _index
        while hasInput, let el = currentElement, cond(el) {
            index += 1
        }
        return input[head..<_index]
    }

    func hasPrefix(_ pf: Input) -> Bool where Input.Element: Equatable {
        zip(rest, pf).allSatisfy({ $0 == $1 })
    }
}

// MARK: Original

public struct _Cursor<C: Collection>: Sequence {
    public typealias Element = Item
    
    public struct Item {
        public enum Ordinal { case first, nth, last }
        public let value: C.Element
        public let index: Int
        public let count: Int
        public let window: C.SubSequence
        public var isFirst: Bool { index == 0 }
        public var isLast: Bool  { index == count - 1 }
        
        public var ordinal: Ordinal {
            switch index {
                case 0: return .first
                case count - 1: return .last
                default: return .nth
            }
        }
        
        public func peek(_ ndx: Int) -> C.SubSequence {
            let currentIndex = window.index(window.startIndex, offsetBy: ndx)
            let nextIndex = window.index(currentIndex, offsetBy: ndx)
            return currentIndex < nextIndex ? window[currentIndex..<nextIndex] : window[nextIndex..<currentIndex]
        }
    }
    
    private let collection: C
    
    public init(_ collection: C) {
        self.collection = collection
    }
    
    public func makeIterator() -> Iterator {
        Iterator(collection: collection)
    }
    
    public struct Iterator: IteratorProtocol {
        private let collection: C
        private let count: Int
        private var index: Int = 0
        private var elementIterator: C.Iterator
        
        init(collection: C) {
            self.collection = collection
            self.count = collection.count
            self.elementIterator = collection.makeIterator()
        }
        
        public mutating func next() -> Item? {
            guard let value = elementIterator.next() else { return nil }
            defer { index += 1 }
            return Item(
                value: value,
                index: index,
                count: count,
                window: collection[...]
            )
        }
        
        public mutating func jump(_ cnt: Int) {
            index += cnt
            if index > count - 1 {
                index = count - 1 // Max to the end
            }
            if index < 0 { index = 0 }
        }
    }
}


//#if canImport(Playgrounds)
//import Playgrounds
//
//#Playground {
//    let list = ["A", "b", "c", "d"]
//    for item in Cursor(list) {
//        (item.value, item.ordinal)
//    }
//}
//#endif

