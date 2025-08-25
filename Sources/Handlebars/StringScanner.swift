//
//  StringScanner.swift
//  Handlebars
//
//  Created by Jason Jobe on 8/24/25.
//


import Foundation

/// `StringScanner` is a fast scanner for Strings and String-like objects.
/// It's used to extract structured bits from unstructured strings, while
/// avoiding making extra copies of string bits until absolutely necessary.
/// You can build Scanners over Substrings, allowing you to scan
/// parts of strings and use smaller, more specialized scanners to extract bits
/// of that String without needing to reuse another scanner.
public struct StringScanner<Input: StringProtocol> {
    let input: Input
    var index: Input.Index
    
    /// Creates a new scanner over the provided input.
    /// - Parameter input: The string or substring to scan.
    public init(_ input: Input) {
        self.input = input
        self.index = input.startIndex
    }
    
    public var currentChar: Character? {
        return index < input.endIndex ? input[index] : nil
    }
    
    public func peek(by: Int = 1) -> Input.SubSequence? {
        if by < 0 {
            let startIndex = input.index(index, offsetBy: by, limitedBy: input.startIndex) ?? input.startIndex
            return input[startIndex..<index]
        } else {
            let endIndex = input.index(index, offsetBy: by, limitedBy: input.endIndex) ?? input.endIndex
            return input[index..<endIndex]
        }
    }
    
    /// Advances the cursor, returning the SubSequence of `count`
    mutating func take(count: Int = 1) -> Input.SubSequence {
        let start = index
        _ = input.formIndex(&index, offsetBy: count, limitedBy: input.endIndex)
        return input[start..<index]
    }

    /// Moves the cursor ahead by `count`
    mutating func advance(by count: Int = 1) {
        _ = input.formIndex(&index, offsetBy: count, limitedBy: input.endIndex)
    }
    
    /// Whether this scanner has exhausted all of its input string.
    public var hasInput: Bool {
        return currentChar != nil
    }
    
    /// Attempts to scan an Number from the current position in the input string.
    /// If not decimal is found then return an Integer, otherwise, return a Double.
    /// If the cursor is not pointing to an integer or real, this function returns `nil`.

    public mutating func scanNumber() -> (any Numeric)? {
        guard isAt(.decimalDigits) else {
            return nil
        }
        let start = index
        
        _ = scan(.decimalDigits)

        if currentChar == "." {
            _ = scan(".")
            _ = scan(.decimalDigits)
            return Double(input[start..<index]) ?? 0.0
        } else {
            return Int(input[start..<index]) ?? 0
        }
    }

    /// Attempts to scan an integer from the current position in the input string.
    /// If the cursor is not pointing to an integer, this function returns `nil`.
    public mutating func scanInt() -> Int? {
        guard isAt(.decimalDigits) else {
            return nil
        }
        let int = scan(.decimalDigits)
        return Int(int)
    }
    
    /// Scans multiple integers separated by the provided separator set.
    /// It stops scanning as soon as the first non-integer character is found
    /// that is not in the separator set.
    ///
    /// - Parameter separator: The character set that separates each integer
    ///                        in the input.
    /// - Returns: All integers from the current cursor position, separated by
    ///            the separator character.
    public mutating func scanInts(separatedBy separator: CharacterSet) -> [Int] {
        let rawInts = scan(.decimalDigits, separatedBy: separator)
        return rawInts.map { Int($0)! }
    }
    
    
    /// Scans the provided characters in the provided character set, each time
    /// skipping characters in a separator character set.
    /// You can use this to extract similar data separated by a given separator.
    ///
    /// - Parameters:
    ///   - chars: The set of characters you're trying to keep.
    ///   - separator: The set of separator characters between each entry
    ///                you're scanning.
    /// - Returns: All substrings that matched the initial character set with the
    ///            `separator` set between them.
    public mutating func scan(
        _ chars: CharacterSet,
        separatedBy separator: CharacterSet
    ) -> [Input.SubSequence] {
        var results = [Input.SubSequence]()
        repeat {
            results.append(scan(chars))
            guard isAt(separator) else {
                break
            }
            skip(separator)
        } while isAt(chars)
        return results
    }
    
    /// All remaining input that has yet to be consumed. Useful for debugging.
    public var remainingInput: Input.SubSequence {
        return input[index...]
    }
    
    /// Determines if the scanner is currently pointing to a member of a character
    /// set.
    /// - Parameter chars: The character set you're testing the current character
    ///                    against.
    public func isAt(_ chars: CharacterSet) -> Bool {
        guard let c = currentChar else { return false }
        for scalar in c.unicodeScalars {
            if !chars.contains(scalar) { return false }
        }
        return true
    }
    
    /// Scans and saves all characters up to, but not including, the first
    /// character that is contained within the provided character set.
    ///
    /// - Parameter chars: The character set that signals the end of the scanned
    ///                    region.
    /// - Returns: The sequence of characters up to, but not including, the first
    ///            character that appears in the provided character set.
    public mutating func scanUpTo(_ chars: CharacterSet) -> Input.SubSequence {
        let start = index
        skip(to: chars)
        return input[start..<index]
    }
    
    
    /// Scans and saves all characters that are contained within the provided
    /// character set.
    ///
    /// - Parameter chars: The character set that each scanned character must
    ///                    belong to.
    /// - Returns: The sequence of characters that all are contained within the
    ///            character set, starting at the current character.
    public mutating func scan(_ chars: CharacterSet) -> Input.SubSequence {
        let start = index
        skip(chars)
        return input[start..<index]
    }
    
    public mutating func scan(_ char: Character) -> Input.SubSequence {
        let start = index
        if char == currentChar {
            advance()
        }
        return input[start..<index]
    }

    /// Scans the exact string or substring provided, and returns its range in the
    /// input string, or `nil` if it did not match.
    ///
    /// - Parameter string: The string to match.
    /// - Returns: The range in the input string where this string first
    ///            appears after the current cursor, or `nil` if the string
    ///            does not appear.
    public mutating func scan<Str: StringProtocol>(
        _ string: Str
    ) -> Input.SubSequence? {
        let start = index
        guard skip(string) else { return nil }
        return input[start..<index]
    }
    
    /// Skips the exact string or substring provided, if it is currently at the
    /// Scanner's cursor.
    ///
    /// - Parameter string: The string to skip.
    @discardableResult
    public mutating func skip<Str: StringProtocol>(_ string: Str) -> Bool {
        let start = index
        var scanner = StringScanner<Str>(string)
        while let char = currentChar, let strChar = scanner.currentChar {
            if char == strChar {
                advance()
                scanner.advance()
            } else {
                index = start
                return false
            }
        }
        return !scanner.hasInput
    }
    
    /// Skips all characters up to, but not including, the first character in the
    /// provided character set.
    ///
    /// - Parameter chars: The character set that signals the end of the skipped
    ///                    region.
    public mutating func skip(to chars: CharacterSet) {
        while currentChar != nil && !isAt(chars) {
             advance()
        }
    }
    
    /// Skips all characters in the provided character set.
    ///
    /// - Parameter chars: The character set that should be skipped.
    public mutating func skip(_ chars: CharacterSet) {
        while isAt(chars) {
            advance()
        }
    }
}
