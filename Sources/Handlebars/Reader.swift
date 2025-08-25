//
//  Reader.swift
//  Handlebars
//
//  Created by Jason Jobe on 7/25/25.
//
import Foundation

/// A lightweight recursive reader/tokenizer for simple structured text.
///
/// `Reader` consumes an input string via an underlying `StringScanner` and
/// produces loosely-typed tokens that are convenient for quick prototyping
/// and exploratory parsing. It recognizes:
///
/// - Delimited lists: `(...)`, `[...]`, `{...}` → returned as `[Any]`
/// - Key–value pairs: `key: value` → returned as `KeyValue`
/// - Operator runs: sequences of operator characters → `OperatorSymbol`
/// - Identifiers: runs of letters → `StringProtocol` (as scanned)
/// - Numbers: using `StringScanner.scanNumber()`
/// - Punctuation and individual characters when nothing else matches
/// - Multiline text blocks delimited by `#|` and `|#` → `TextBlock`
///
/// The reader skips leading whitespace/newlines before each token and supports
/// nesting for delimited lists. Closing delimiters encountered during a nested
/// read are returned as-is so outer contexts can terminate correctly.
///
/// ### Example
/// ```swift
/// let r = Reader(text: "(a: 1) [x y z] #|\nhello\n|#")
/// var out: [Any] = []
/// while let t = r.read() { out.append(t) }
/// // `out` now holds tokens in the order they were read
/// ```
public class Reader<Input: StringProtocol>  {
    /// The underlying scanner/cursor that advances through the input.
    /// Exposed for advanced use; typical clients only call `read()`.
    var curs: StringScanner<Input>
    
    /// Creates a reader for the given input.
    /// - Parameter text: The source text to be scanned.
    public init(text: Input) {
        self.curs = .init(text)
    }
    
    /// Reads and returns the next token from the input.
    ///
    /// Skips leading whitespace/newlines, then chooses the next token based on the
    /// current character:
    /// - Delimiter opens `(`, `[`, `{` → parses a nested list until the matching close
    /// - Delimiter closes `)`, `]`, `}` → returned so outer callers can end their loop
    /// - `#|` → parses a `TextBlock` until `|#`
    /// - Letters → scans a contiguous identifier
    /// - Decimal digits → delegates to `StringScanner.scanNumber()`
    /// - Operator characters (see `op_chars`) → returns `OperatorSymbol`
    /// - Punctuation/other → returns the raw character/string
    ///
    /// After producing a token, if it is immediately followed by a `:` the reader
    /// parses the following value and returns a `KeyValue`.
    /// - Returns: The next token (`[Any]`, `KeyValue`, `OperatorSymbol`, `TextBlock`,
    ///   numeric/identifier/punctuation tokens) or `nil` at end of input.
    public func read() -> Any? {
        curs.skip(.whitespacesAndNewlines)
        guard curs.hasInput
        else { return nil }

        return switch curs {
            // Short circuit to end loops
            case ")": curs.take()
            case "]": curs.take()
            case "}": curs.take()
                
            case op_chars:
                OperatorSymbol(value: curs.scan(op_chars))
            case "[":
                loop(from: "[", to: "]")
                
            case "{":
                loop(from: "{", to: "}")
                
            case "(":
                loop(from: "(", to: ")")
                
            case "#|":
                text(from: "#|", to: "|#")
                
            case CharacterSet.letters:
                curs.scan(.letters)
                
            case CharacterSet.decimalDigits:
                curs.scanNumber()
                
            case CharacterSet.punctuationCharacters:
                curs.scan(.punctuationCharacters)
                
            default:
                curs.take()
        }
        //        if let item, curs.currentChar == ":" {
        //            curs.advance()
        //            return KeyValue(key: item, value: read())
        //        } else {
        //            return item
        //        }
    }
    
    /// The set of characters treated as operator symbols when scanned contiguously.
    let op_chars = CharacterSet(charactersIn: "!=~<>+-*/$%^&|:")
}

// MARK: Switch Case Matching
func ~=<P: StringProtocol>(lhs: CharacterSet, rhs: StringScanner<P>) -> Bool {
    if let ch = rhs.currentChar?.unicodeScalars.first {
        lhs.contains(ch)
    } else {
        false
    }
}

func ~=<P: StringProtocol>(lhs: String, rhs: StringScanner<P>) -> Bool {
    rhs.remainingInput.hasPrefix(lhs)
}

extension Reader {
    /// Parses a multiline text block.
    ///
    /// Skips the opening delimiter, trims leading whitespace/newlines, then
    /// collects lines until the closing delimiter is reached. Blank separator
    /// lines are preserved.
    /// - Parameters:
    ///   - key: A label to attach to the resulting `TextBlock` (defaults to "text").
    ///   - from: The opening delimiter (e.g., `#|`).
    ///   - to: The closing delimiter (e.g., `|#`).
    /// - Returns: A `TextBlock` containing captured lines, or `nil` if the open
    ///   delimiter is not present at the current position.
    func text(
        key: String = "text",
        from: any StringProtocol,
        to end: any StringProtocol
    ) -> TextBlock? {
        _ = curs.skip(from)
        curs.skip(.whitespacesAndNewlines)
        let lines = curs.lines(upto: end).map(\.description)
        return TextBlock(key: key, lines: lines)
    }
    
    /// Parses a delimited list by repeatedly calling `read()` until the matching
    /// closing delimiter is encountered.
    /// - Parameters:
    ///   - from: The opening delimiter to consume (e.g., "(", "[", "{").
    ///   - to: The closing delimiter that terminates the loop.
    /// - Returns: The array of parsed elements. If the opening delimiter is not
    ///   present, returns an empty array.
    func loop(from: any StringProtocol, to: any StringProtocol) -> [Any] {
        guard curs.skip(from) else { return [] }
        var arr: [Any] = []
        while let elem = read() {
            if to.eq(elem) { break }
            arr.append(elem)
        }
        curs.skip(to)
        return arr
    }
}

// MARK: Token Types
public struct OperatorSymbol: CustomStringConvertible {
    public var description: String { String(value) }
    public let value: any StringProtocol
}

public struct KeyValue: CustomStringConvertible {
    public let key: Any // any StringProtocol
    public let value: Any?
    public var description: String {
        if let value {
            "(\(String(describing: key)): \(String(describing: value)))"
        } else {
            "(\(String(describing: key)): nil)"
        }
    }
    public init(key: Any, value: Any?) {
        self.key = key
        self.value = value
    }
}

public struct TextBlock: CustomStringConvertible {
    public let key: any StringProtocol
    public let lines: [String]
    public var description: String {
        "(\(key)): \(lines)"
    }
    public init(key: any StringProtocol, lines: [String]) {
        self.key = key
        self.lines = lines
    }
}

extension StringScanner {
    
    func hasPrefix(_ str: any StringProtocol) -> Bool {
        let ndx = index.utf16Offset(in: input)
        guard ndx + str.count <= input.count else { return false }
        let end = input.index(index, offsetBy: str.count)
        return input[index..<end] == str
    }
    
    mutating func lines(upto del: any StringProtocol
    ) -> [any StringProtocol] {
        var lines: [any StringProtocol] = []
        var start = index
        
        while hasInput {
            if isAt(.newlines) {
                // NOTE: We have check for newlines one at a time
                // and do this little dance to make sure catch
                // blank separator lines
                let line = input[start..<index]
                if line.hasPrefix(del) {
                    break
                }
                if line.hasPrefix("\n") {
                    lines.append("\n")
                    lines.append(line.dropFirst())
                } else {
                    lines.append(line)
                }
                _ = skip("\n")
                start = index
            } else if hasPrefix(del) {
                // End-of-Block
                let last_line = input[start..<index]
                    .description
                    .trimmingCharacters(in: .whitespaces)
                if !last_line.isEmpty {
                    lines.append(last_line)
                }
                _ = skip(del)
                break
            } else if !hasInput {
                // EOF reached, capture remaining text
                lines.append(input[start..<input.endIndex])
                break
            }
            advance()
        }
        return lines
    }
}

extension StringProtocol {
    
    func notEq(_ any: Any?) -> Bool {
        !self.eq(any)
    }
    
    func eq(_ any: Any?) -> Bool {
        guard let any, let str = any as? any StringProtocol
        else { return false }
        return self == str
    }
}
