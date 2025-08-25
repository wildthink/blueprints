//
//  KituraMiniHandlebarsError.swift
//  Handlebars
//
//  Created by Jason Jobe on 8/25/25.
//


/**
 * Copyright Jan Vojáček 2018
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation
//import KituraTemplateEngine;


public enum KituraMiniHandlebarsError: Error {
    case RangeError
    case KeyForArrayMissing
    case UnableToEncodeValue
    case UnableToCastJSONtoDictionary
}

public struct KituraMiniHandlebarsOptions: RenderingOptions {
    
    /// Constructor
    public init () {}
}

public class MiniHandlebars: TemplateEngine {
    
    public let fileExtension: String = "html";
    
    public init () {}
    
    /// Public method to generate HTML.
    ///
    /// - Parameters:
    ///   - filePath: The path of the template file.
    ///   - context: A set of variables in the form of a Dictionary of Key/Value pairs.
    /// - Returns: String containing a HTML.
    /// - Throws: Template reading error.
    public func render (filePath: String, context: [String: Any]) throws -> String {
        return try render(filePath: filePath, context: context, options: KituraMiniHandlebarsOptions())
    }
    
    /// Public method to generate HTML.
    ///
    /// - Parameters:
    ///   - filePath: The path of the template file.
    ///   - context: A set of variables in the form of a Dictionary of Key/Value pairs.
    ///   - options: KituraMiniHandlebarsOptions. *Note:* no options available at the time.
    /// - Returns: String containing a HTML.
    /// - Throws: Template reading error.
    public func render (filePath: String, context: [String: Any], options: KituraMiniHandlebarsOptions) throws -> String {
        
        let html: String = try String(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8);
        
        return try render(from: html, context: context);
    }
    
    /// Public method to generate HTML with using encodable structure.
    ///
    /// - Parameters:
    ///   - filePath: The path of the template file.
    ///   - value: Encodable structure.
    ///   - key: Key to itarate encodagle structure in template file with in case of array in the value field.
    ///   - options: KituraMiniHandlebarsOptions. *Note:* no options available at the time.
    ///   - templateName: *Note:* no available at the time.
    /// - Returns: String containing a HTML.
    /// - Throws: Template reading error.
    public func render<T: Encodable>(filePath: String, with value: T, forKey key: String?, options: RenderingOptions, templateName: String) throws -> String {
        
        // Throw an error in case that value is an array and key which to map the array to is not present.
        let valueIsArray: Bool = value is Array<Any>
        
        if key == nil && valueIsArray {
            throw KituraMiniHandlebarsError.KeyForArrayMissing
        }
        
        var data: Data = Data()
        
        do {
            data = try JSONEncoder().encode(value)
        } catch {
            throw KituraMiniHandlebarsError.UnableToEncodeValue
        }
        
        let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        var jsonArray: [[String: Any]]?
        var jsonBasic: [String: Any]?
        
        if valueIsArray {
            jsonArray = json as? [[String: Any]]
        } else {
            jsonBasic = json as? [String: Any]
        }
        
        if jsonArray == nil && jsonBasic == nil {
            throw KituraMiniHandlebarsError.UnableToCastJSONtoDictionary
        }
        
        var context: [String: Any]
        
        if jsonArray != nil {
            let key = key!
            context = [key: jsonArray!]
        } else {
            context = jsonBasic!
        }
        
        return try self.render(filePath: filePath, context: context)
    }
    
    /// Public static method to generate HTML.
    ///
    /// - Parameters:
    ///   - from: String from which to generate HTML.
    ///   - context: A set of variables in the form of a Dictionary of Key/Value pairs.
    /// - Returns: String containing a HTML.
    public func render (from: String, context: [String: Any]) throws -> String {
        
        if from.isEmpty {
            return from;
        }
        
        var commands = getAllCommands(from: from)
        var rendered: String = "";
        var cp = context
        try render(commands: &commands, context: &cp, into: &rendered)
        return rendered
    }
        
    func render (
        commands: inout [Command],
        context: inout [String: Any],
        into rendered: inout String
    ) throws {

        var conds: [(Command,Bool)] = []
        var shouldOutput: Bool { (conds.last?.1) ?? true }

        // process commands
        for cmd in commands {
            switch cmd.op {
            case .if:
                // if true process until else/endif
                let flag = context.boolValue(forKey: cmd.argv.first)
                conds.append((cmd, flag))
//                if let value = context.value(forKey: cmd.argv.first) {
//                    // NOTE: non-Bool, non-nil -> TRUE
//                    let flag = (value as? Bool) ?? true
//                    conds.append((cmd, flag))
//                } else {
//                    conds.append((cmd, false))
//                }
            case .else:
                guard let (cmd, flag) = conds.last
                else {
                    throw CommandError.missing_if
                }
                // NOTE: flip the flag on its #if
                conds.removeLast()
                // CHECK: for "else" vs "else if cond"
                if cmd.argv.isEmpty {
                    conds.append((cmd, !flag))
                } else {
                    let myflag = context.boolValue(forKey: cmd.argv.last)
                    conds.append((cmd, myflag))
                }

            case .endif:
                guard let _ = conds.last
                else {
                    throw CommandError.missing_if
                }
                conds.removeLast()

            case _ where !shouldOutput:
                continue
                
            case .text:
                rendered.append(cmd.raw.description)
                
            case .eval:
                if let value = context.value(forKey: cmd.argv.first) {
                    rendered.append(String(describing: value))
                } else {
                    print("NO VALUE for", cmd.argv.first)
                }
            case .each:
                // FIXME: Should wrap a Cursor around the array
                // FIXME: ONLY uses the first item
                guard let list = context.value(forKey: cmd.argv.first) as? Array<Any>
                else { continue }
                context["."] = list.first
//                var ctx = context
//                for item in list {
//                    ctx["."] = item
//                    try render(commands: &commands, context: ctx, into: &rendered)
//                }
            case .include:
                rendered.append(cmd.raw.description)
            }
        }
    }
    
    /// Returns the exact position of a desired end tag of a command in the array of commands offseted by an offset specified.
    ///
    /// - Parameters:
    ///   - commands: Array of commands.
    ///   - offset: Offset of a desired conditional ending tag to be found.
    /// - Returns: Index of desired tag.
    private static func getIndexOfEndTag (commands: Array<String>, offset: Int, endTag: String) -> Int? {
        
        var endIndexIterations: Int = -1;
        
        let indexOfEnd = commands.firstIndex(where: { (command) -> Bool in
            
            if command.range(of: endTag) != nil {
                
                endIndexIterations += 1;
                
                if endIndexIterations == offset {
                    return true;
                }
            }
            
            return false;
        });
        
        return indexOfEnd;
    }
    
    /// Returns offset of a right ending tag of an requested command currently being processed (on the first place in the 'commands' parameter).
    ///
    /// - Parameter commands: Array of commands.
    /// - Returns: Offset of a right end tag of the first processed conditional command..
    private static func getEndCommandOffset (commands: Array<String>, startTag: String, endTag: String) -> Int {
        
        var commandsToProcess: Array<String> = commands;
        commandsToProcess.removeFirst();
        
        var offset: Int = 0;
        var start: Int = 0;
        var end: Int = 0;
        
        for command in commandsToProcess {
            
            if command.range(of: startTag) != nil {
                start += 1;
                continue;
            }
            
            if command.range(of: endTag) != nil {
                
                if start == end {
                    return offset;
                }
                
                end += 1;
                offset += 1;
            }
        }
        
        return offset;
    }
    

    /// Iterates over a template and finds all valid commands of the KituraMiniHandlebars.
    ///
    /// - Parameter from: String of an template.
    /// - Returns: All KituraMiniHandlebars commands to be found in the string.

    private func getAllCommands (from: String) -> Array<Command> {
        
        var commands: [Command] = []
        
        var curs = StringScanner(from)
        
        var cpos = curs.index
        
        while curs.hasInput {
            switch curs {
            case "{{":
                let run = from[cpos..<curs.index]
                let cmd = Command(op: .text, raw: run, range: cpos..<curs.index)
                cpos = curs.index
                commands.append(cmd)
                curs.advance(by: 2)

            case "}}":
                curs.advance(by: 2)
                let run = from[cpos..<curs.index]
                let cmd = Command(op: .eval, raw: run, range: cpos..<curs.index)
                cpos = curs.index
                commands.append(cmd)
                
            default:
                curs.advance()
            }
        }

        return commands
        
        func read_cmd() {}
        
    }
    
}

enum CommandError: Error {
    case missing_if
    case unknown(String)
}

enum CommandOperator {
    case text, eval
    case `if`, `else`, endif, each
    case include
}

struct Command {
    var op: CommandOperator
    var raw: Substring
    var range: Range<String.Index>
    var argv: [Substring]
    var index: Int { raw.distance(from: raw.startIndex, to: range.lowerBound) }

    func eval() {
        
    }
    
    init(op: CommandOperator, raw: Substring, range: Range<String.Index>) {
        self.op = op
        self.raw = raw
        self.range = range
        self.argv = []
        if op != .text {
            parse()
        }
    }
    
    mutating func parse() {
        var curs = StringScanner(raw)
        
        while curs.hasInput {
            curs.skip(CharacterSet.whitespaces)
            switch curs {
            case "#if":
                op = .if
                curs.advance(by: 3)

            case "/if":
                op = .if
                curs.advance(by: 3)

            case "#each":
                op = .each
                curs.advance(by: 5)
                
            case "else":
                op = .else
                curs.advance(by: 4)
                
            case "#":
                op = .include
                curs.advance()
                
            case "{{", "}}":
                curs.advance(by: 2)
                
            case symbolset:
                let str = curs.scan(symbolset)
                argv.append(str)
                
            default:
                curs.advance()
            }
        }
    }
    
    var symbolset: CharacterSet { Self.symbolset }
    
    static let symbolset: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: ".")
        return set}()
}

extension Command: CustomStringConvertible {
    var description: String {
        switch op {
        case .text:
            "TEXT " + String(raw.prefix(12))
        case .eval:
            raw.description
        default:
            "\(op)(\(argv.joined(separator: ", ")))"
        }
    }
}
