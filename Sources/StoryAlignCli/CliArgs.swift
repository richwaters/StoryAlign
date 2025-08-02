//
// CliArgs.swift
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation

struct CliError: Error, CustomStringConvertible {
    let description: String
    init(_ desc: String) { self.description = desc }
}


protocol CliArgs: Codable {
    associatedtype CodingKeys: CodingKey & CaseIterable
    var positionals: [String]? { get set }
}

extension CliArgs {
    static var validOptionKeys: Set<String> {
        Set(CodingKeys.allCases.map { $0.stringValue })
    }
}


    
struct CliArgsParser {
    func parse<T:CliArgs>(from rawArgs: [String] = Array(CommandLine.arguments)) throws -> T {
        let args = Array(rawArgs.dropFirst())
        let (raw, pos, dashFlags) = jsonAndPositionals(from: args)
        if !dashFlags.isEmpty {
            throw CliError("Unknown argument(s): \(dashFlags.joined(separator: ", "))")
        }
        
        let invalid = raw.keys.filter { !T.validOptionKeys.contains($0) }
        if !invalid.isEmpty {
            throw CliError("Unknown argument(s): \(invalid.joined(separator: ", "))")
        }
        
        let data = try JSONSerialization.data(withJSONObject: raw)
        
        do {
            var obj = try JSONDecoder().decode(T.self, from: data)
            obj.positionals = pos
            return obj
        }
        
        catch let DecodingError.dataCorrupted(context) {
            let path = context.codingPath
                .map { $0.stringValue }
                .joined(separator: ".")
            let badVal = raw[path] as? String ?? "???"
            throw CliError("Unknown value '\(badVal)' for '\(path)'")
        }
        catch let DecodingError.typeMismatch(type, context) {
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            let badVal = raw[path] as? String ?? "???"

            if type == Bool.self  {
                // This is to handle case where the last option is a flag that doesn't take an argument,
                // and the parser believes the positional to be that argument. This only occurs if the user
                // has used the key<space>value, instead of the --key=value. Anyway. this adjusts for that
                let isLastFlag = {
                    let lastFlag = args.reversed().first { $0.hasPrefix("--") }
                    
                    guard let lastFlag else {
                        return false
                    }
                    return lastFlag.safeSubstring(from: 2) == path
                }()
                if isLastFlag {
                    var adjustedVals = raw
                    adjustedVals[path] = true
                    var adjustedPositions = pos
                    adjustedPositions.insert(String(describing: badVal), at: 0)
                    let fixedData = try JSONSerialization.data(withJSONObject: adjustedVals)
                    var obj = try JSONDecoder().decode(T.self, from: fixedData)
                    obj.positionals = adjustedPositions
                    return obj
                }
            }
            
            throw CliError( "Invalid value: '\(badVal)' for '\(path)': expected \(type)" )
        } catch let DecodingError.keyNotFound(key, _) {
            throw CliError( "Missing required argument: \(key.stringValue)" )
        } catch {
            throw CliError("Failed to parse arguments: \(error)")
        }
    }
    
    func jsonAndPositionals(from rawArgs: [String] ) -> (options: [String: Any], positionals: [String], unknown: [String])
    {
        var dict: [String: Any] = [:]
        var positionals: [String] = []
        var unknown: [String] = []
        
        var args = rawArgs[...]
        var parsingOptions = true
        
        while let arg = args.first {
            args = args.dropFirst()
            
            if parsingOptions, arg == "--" {
                parsingOptions = false
                continue
            }
            
            if parsingOptions {
                if arg.starts(with: "--") {
                    let stripped = String(arg.dropFirst(2))
                    
                    // Handle --key=value
                    if let eqIndex = stripped.firstIndex(of: "=") {
                        let key = String(stripped[..<eqIndex])
                        let value = String(stripped[stripped.index(after: eqIndex)...])
                        /*
                        if let intVal = Int(value) {
                            dict[key] = intVal
                        } else if let doubleVal = Double(value) {
                            dict[key] = doubleVal
                        } else {
                            dict[key] = value
                        }
                         */
                        dict[key] = parseValue(value)
                    } else {
                        // Handle --key [value] or --flag
                        let key = stripped
                        if let next = args.first, !next.starts(with: "--") {
                            dict[key] = parseValue(next)
                            /*
                            if let intVal = Int(next) {
                                dict[key] = intVal
                            } else if let doubleVal = Double(next) {
                                dict[key] = doubleVal
                            } else {
                                dict[key] = next
                            }*/
                            args = args.dropFirst()
                        } else {
                            dict[key] = true
                        }
                    }
                    
                } else if arg.starts(with: "-") {
                    unknown.append(arg)
                } else {
                    positionals.append(arg)
                }
            } else {
                positionals.append(arg)
            }
        }
        
        return (dict, positionals, unknown)
    }
    
    private func parseValue(_ raw: String) -> Any {
        if raw.count >= 2,
           let first = raw.first,
           let last  = raw.last,
           (first == "\"" && last == "\"") || (first == "'" && last == "'")
        {
            return String(raw.dropFirst().dropLast())
        }
        if let i = Int(raw)    { return i }
        if let d = Double(raw) { return d }
        return raw
    }
}
