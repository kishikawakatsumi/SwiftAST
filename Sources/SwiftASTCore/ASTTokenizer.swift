////////////////////////////////////////////////////////////////////////////
//
// Copyright 2019 Kishikawa Katsumi.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Foundation

class ASTTokenizer {
    class State {
        enum Mode {
            case plain
            case token
            case value
            case path
            case array
            case symbol
            case string
            case stringEscape
            case newline
            case indent
        }

        var mode = Mode.plain
        var tokens = [ASTToken]()
        var storage = ""
        var input: String

        init(input: String) {
            self.input = input
        }
    }

    func tokenize(source: String) -> [ASTToken] {
        var lines = [String]()
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("(inherited_conformance") ||  trimmed.hasPrefix("(normal_conformance") || trimmed.hasPrefix("(abstract_conformance") ||
                trimmed.hasPrefix("(specialized_conformance") || trimmed.hasPrefix("(assoc_type") ||
                trimmed.hasPrefix("(value req") || !trimmed.hasPrefix("(") {
                continue
            }
            lines.append(String(line))
        }

        let state = State(input: lines.joined(separator: "\n"))
        for character in state.input {
            switch state.mode {
            case .plain:
                switch character {
                case "'":
                    state.mode = .symbol
                case "\"":
                    state.mode = .string
                case "\n":
                    state.mode = .newline
                    state.storage = ""
                case "(", ")", ":":
                    state.tokens.append(ASTToken(type: .token, value: String(character)))
                case " ":
                    break
                default:
                    state.mode = .token
                    state.storage = String(character)
                }
            case .token:
                switch character {
                case "'":
                    state.tokens.append(ASTToken(type: .token, value: state.storage))
                    state.mode = .symbol
                    state.storage = ""
                case "\"":
                    state.tokens.append(ASTToken(type: .token, value: state.storage))
                    state.mode = .string
                    state.storage = ""
                case " ":
                    state.tokens.append(ASTToken(type: .token, value: state.storage))
                    state.mode = .plain
                    state.storage = ""
                case "\n":
                    state.tokens.append(ASTToken(type: .token, value: state.storage))
                    state.mode = .newline
                    state.storage = ""
                case "=":
                    state.tokens.append(ASTToken(type: .token, value: state.storage))
                    state.tokens.append(ASTToken(type: .token, value: String(character)))
                    if state.storage == "location" {
                        state.mode = .path
                    } else {
                        state.mode = .value
                    }
                    state.storage = ""
                case "(", ")", ":":
                    state.tokens.append(ASTToken(type: .token, value: state.storage))
                    state.tokens.append(ASTToken(type: .token, value: String(character)))
                    state.mode = .plain
                    state.storage = ""
                default:
                    state.storage += String(character)
                }
            case .value:
                switch character {
                case "[":
                    state.mode = .array
                case " ":
                    state.tokens.append(ASTToken(type: .token, value: state.storage))
                    state.mode = .plain
                    state.storage = ""
                case "'":
                    state.mode = .symbol
                case "\"":
                    state.mode = .string
                case "\n":
                    state.tokens.append(ASTToken(type: .token, value: state.storage))
                    state.mode = .newline
                    state.storage = ""
                default:
                    state.storage += String(character)
                }
            case .path:
                switch character {
                case "[":
                    state.mode = .array
                case " ":
                    if state.storage.contains(":") {
                        state.tokens.append(ASTToken(type: .token, value: state.storage))
                        state.mode = .plain
                        state.storage = ""
                    } else {
                        state.storage += String(character)
                    }
                case "'":
                    state.mode = .symbol
                case "\"":
                    state.mode = .string
                case "\n":
                    state.tokens.append(ASTToken(type: .token, value: state.storage))
                    state.mode = .newline
                    state.storage = ""
                default:
                    state.storage += String(character)
                }
            case .array:
                switch character {
                case "]":
                    state.tokens.append(ASTToken(type: .token, value: state.storage))
                    state.mode = .plain
                    state.storage = ""
                default:
                    state.storage += String(character)
                }
            case .symbol:
                switch character {
                case "'":
                    state.tokens.append(ASTToken(type: .symbol, value: state.storage))
                    state.mode = .plain
                    state.storage = ""
                default:
                    state.storage += String(character)
                }
            case .string:
                switch character {
                case "\"":
                    state.tokens.append(ASTToken(type: .string, value: state.storage))
                    state.mode = .plain
                    state.storage = ""
                case "\\":
                    state.mode = .stringEscape
                default:
                    state.storage += String(character)
                }
            case .stringEscape:
                switch character {
                case "\"", "\\", "'", "t", "n", "r", "0":
                    state.mode = .string
                    state.storage += "\\" + String(character)
                default:
                    fatalError("unexpected '\(character)' in string escape")
                }
            case .newline:
                switch character {
                case " ":
                    state.mode = .indent
                    state.storage = String(character)
                case "(", ")", ":":
                    state.tokens.append(ASTToken(type: .token, value: String(character)))
                    state.mode = .plain
                case "\n":
                    break
                default:
                    state.mode = .token
                    state.storage = String(character)
                }
            case .indent:
                switch character {
                case " ":
                    state.storage += " "
                case "\n":
                    state.mode = .newline
                    state.storage = ""
                case "(", ")", ":":
                    state.tokens.append(ASTToken(type: .indent(state.storage.count), value: state.storage))
                    state.tokens.append(ASTToken(type: .token, value: String(character)))
                    state.mode = .plain
                default:
                    state.tokens.append(ASTToken(type: .indent(state.storage.count), value: state.storage))
                    state.mode = .token
                    state.storage = String(character)
                }
            }
        }
        if !state.storage.isEmpty {
            switch state.mode {
            case .token, .value, .path:
                state.tokens.append(ASTToken(type: .token, value: state.storage))
            case .symbol:
                state.tokens.append(ASTToken(type: .symbol, value: state.storage))
            case .string:
                state.tokens.append(ASTToken(type: .string, value: state.storage))
            default:
                break
            }
        }
        return state.tokens
    }
}
