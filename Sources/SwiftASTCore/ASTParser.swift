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

class ASTParser {
    class State {
        let root: ASTNode<[ASTToken]>

        init(root: ASTNode<[ASTToken]>) {
            self.root = root
        }
    }

    func parse(root: ASTNode<[ASTToken]>) -> AST {
        let state = State(root: root)
        return parseSourceFileNode(node: state.root)
    }

    private func parseSourceFileNode(node sourceFileNode: ASTNode<[ASTToken]>) -> AST {
        var declarations = [Declaration]()
        for node in sourceFileNode.children {
            for token in node.value {
                switch (token.type, token.value) {
                case (.token, "top_level_code_decl"):
                    declarations.append(.topLevelCode(parseTopLevelCodeDeclarationNode(node: node)))
                case (.token, "import_decl"):
                    declarations.append(.import(parseImportDeclarationNode(node: node)))
                case (.token, "struct_decl"):
                    declarations.append(.struct(parseStructDeclarationNode(node: node)))
                case (.token, "class_decl"):
                    declarations.append(.class(parseClassDeclarationNode(node: node)))
                case (.token, "enum_decl"):
                    declarations.append(.enum(parseEnumDeclarationNode(node: node)))
                case (.token, "extension_decl"):
                    declarations.append(.extension(parseExtensionDeclarationNode(node: node)))
                case (.token, "func_decl"):
                    declarations.append(.function(parseFunctionDeclarationNode(node: node)))
                default:
                    break
                }
            }
        }
        return AST(declarations: declarations)
    }

    private func parseTopLevelCodeDeclarationNode(node: ASTNode<[ASTToken]>) -> TopLevelCodeDeclaration {
        var statements = [Statement]()
        for node in node.children {
            for token in node.value {
                switch (token.type, token.value) {
                case (.token, "brace_stmt"):
                    statements.append(.expression(parseExpressionNode(node: node)))
                default:
                    break
                }
            }
        }
        return TopLevelCodeDeclaration(statements: statements)
    }

    private func parseImportDeclarationNode(node: ASTNode<[ASTToken]>) -> ImportDeclaration {
        let tokens = node.value
        let attributes = parseKeyValueAttributes(tokens: tokens)
        let importKind = attributes["kind"]
        let importPath = parseSymbol(tokens: tokens)!
        return ImportDeclaration(importKind: importKind, importPath: importPath)
    }

    private func parseStructDeclarationNode(node: ASTNode<[ASTToken]>) -> StructDeclaration {
        let tokens = node.value
        let name = parseString(tokens: tokens)!
        let accessLevel = parseAccessLevel(tokens: tokens)
        let typeInheritance = parseInherits(tokens: tokens)
        let members: [StructMember] =
            filter(node: node, matches: "func_decl")
                .map { .declaration(.function(parseFunctionDeclarationNode(node: $0))) } +
            filter(node: node, matches: "var_decl")
                .map { .declaration(.variable(parseVariableDeclarationNode(node: $0))) }
        return StructDeclaration(accessLevel: accessLevel, name: name, typeInheritance: typeInheritance, members: members)
    }

    private func parseClassDeclarationNode(node: ASTNode<[ASTToken]>) -> ClassDeclaration {
        let tokens = node.value
        let name = parseString(tokens: tokens)!
        let accessLevel = parseAccessLevel(tokens: tokens)
        let typeInheritance = parseInherits(tokens: tokens)
        let members: [ClassMember] =
            filter(node: node, matches: "func_decl")
                .map { .declaration(.function(parseFunctionDeclarationNode(node: $0))) }
        return ClassDeclaration(accessLevel: accessLevel, name: name, typeInheritance: typeInheritance, members: members)
    }

    private func parseEnumDeclarationNode(node: ASTNode<[ASTToken]>) -> EnumDeclaration {
        let tokens = node.value
        let name = parseString(tokens: tokens)!
        let accessLevel = parseAccessLevel(tokens: tokens)
        let typeInheritance = parseInherits(tokens: tokens)
        let members: [EnumMember] =
            filter(node: node, matches: "func_decl")
                .map { .declaration(.function(parseFunctionDeclarationNode(node: $0))) }
        return EnumDeclaration(accessLevel: accessLevel, name: name, typeInheritance: typeInheritance, members: members)
    }

    private func parseExtensionDeclarationNode(node: ASTNode<[ASTToken]>) -> ExtensionDeclaration {
        let tokens = node.value
        let name = tokens[2].value
        let accessLevel = parseAccessLevel(tokens: tokens)
        let typeInheritance = parseInherits(tokens: tokens)
        let members: [ExtensionMember] =
            filter(node: node, matches: "func_decl")
                .map { .declaration(.function(parseFunctionDeclarationNode(node: $0))) }
        return ExtensionDeclaration(accessLevel: accessLevel, name: name, typeInheritance: typeInheritance, members: members)
    }

    private func parseVariableDeclarationNode(node: ASTNode<[ASTToken]>) -> VariableDeclaration {
        let tokens = node.value
        let attributes = parseKeyValueAttributes(tokens: tokens)

        let name: String! = parseString(tokens: tokens) ?? parseSymbol(tokens: tokens)
        let accessLevel = parseAccessLevel(tokens: tokens)
        let type = attributes["type"]!

        return VariableDeclaration(accessLevel: accessLevel, isLet: isLet(tokens: tokens), name: name, type: type, isImmutable: isImmutable(tokens: tokens))
    }

    private func parseFunctionDeclarationNode(node: ASTNode<[ASTToken]>) -> FunctionDeclaration {
        let tokens = node.value

        let name = parseString(tokens: tokens) ?? parseSymbol(tokens: tokens)
        let accessLevel = parseAccessLevel(tokens: tokens)

        var parameters = [Parameter]()
        var body = [Statement]()
        for node in node.children {
            for token in node.value {
                switch (token.type, token.value) {
                case (.token, "parameter_list"):
                    parameters.append(contentsOf: parseParameterListNode(node: node))
                case (.token, "brace_stmt"):
                    body.append(.expression(parseExpressionNode(node: node)))
                default:
                    break
                }
            }
        }

        return FunctionDeclaration(accessLevel: accessLevel, name: name!, parameters: parameters, body: body)
    }

    private func filter(node: ASTNode<[ASTToken]>, matches value: String) -> [ASTNode<[ASTToken]>] {
        var nodes = [ASTNode<[ASTToken]>]()
        for node in node.children {
            let tokens = node.value
            if isImplicit(tokens: tokens) {
                continue
            }
            for token in tokens {
                switch (token.type, token.value) {
                case (.token, value):
                    nodes.append(node)
                default:
                    break
                }
            }
        }
        return nodes
    }

    private func parseExpressionNode(node: ASTNode<[ASTToken]>) -> Expression {
        let tokens = node.value
        let attributes = parseKeyValueAttributes(tokens: tokens)

        let rawValue = tokens[1].value
        let type = attributes["type"]
        let rawLocation = attributes["location"]
        var location: SourceLocation?
        if let rawLocation = rawLocation {
            location = parseLocation(rawLocation)
        }
        let rawRange = attributes["range"]
        var sourceRange: SourceRange?
        if let rawRange = rawRange {
            sourceRange = parseRange(rawRange)
        }
        let decl = attributes["decl"]
        let value = attributes["value"]
        let argumentLabels = attributes["arg_labels"]
        var throwsModifier: String?
        for token in tokens {
            switch (token.type, token.value) {
            case (.token, "nothrow"):
                throwsModifier = "nothrow"
            case (.token, "throws"):
                throwsModifier = "throws"
            case (.token, "rethrows"):
                throwsModifier = "rethrows"
            default:
                break
            }
        }
        let implicit = isImplicit(tokens: tokens)
        var expression = Expression(rawValue: rawValue, type: type, rawLocation: rawLocation, rawRange: rawRange,
                                    location: location, range: sourceRange, decl: decl, value: value, throwsModifier: throwsModifier,
                                    argumentLabels: argumentLabels, isImplicit: implicit, expressions: [])

        for node in node.children {
            let tokens = node.value
            if tokens.count > 1 {
                expression.expressions.append(parseExpressionNode(node: node))
            }
        }
        return expression
    }

    private func parseLocation(_ locationAttribute: String) -> SourceLocation {
        let info = locationAttribute.split(separator: ":")
        let line = Int(info[1])! - 1
        let column = Int(info[2])!
        return SourceLocation(line: line, column: column)
    }

    private func parseRange(_ rangeAttribute: String) -> SourceRange {
        let info = rangeAttribute
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "", with: "")
            .replacingOccurrences(of: " - line", with: "")
            .split(separator: ":")
        let start = SourceLocation(line: Int(info[1])! - 1, column: Int(info[2])! - 1)
        let end = SourceLocation(line: Int(info[3])! - 1, column: Int(info[4])!)
        return SourceRange(start: start, end: end)
    }

    private func parseParameterListNode(node: ASTNode<[ASTToken]>) -> [Parameter] {
        return node.children.map { parseParameter(tokens: $0.value) }
    }

    private func parseParameter(tokens: [ASTToken]) -> Parameter {
        let attributes = parseKeyValueAttributes(tokens: tokens)
        let externalName: String? = attributes["apiName"]
        var localName: String!
        for token in tokens {
            if case .string = token.type {
                localName = token.value
            }
        }
        let type = attributes["type"]!
        return Parameter(externalName: externalName, localName: localName, type: type)
    }

    private func parseKeyValueAttributes(tokens: [ASTToken]) -> [String: String] {
        var attributes = [String: String]()
        for (index, token) in tokens.enumerated() {
            switch (token.type, token.value) {
            case (.token, "="):
                attributes[tokens[index - 1].value] = tokens[index + 1].value
            default:
                break
            }
        }
        return attributes
    }

    private func parseString(tokens: [ASTToken]) -> String? {
        for token in tokens {
            switch token.type {
            case .string:
                return token.value
            default:
                break
            }
        }
        return nil
    }

    private func parseSymbol(tokens: [ASTToken]) -> String? {
        for token in tokens {
            switch token.type {
            case .symbol:
                return token.value
            default:
                break
            }
        }
        return nil
    }

    private func parseAccessLevel(tokens: [ASTToken]) -> String {
        let attributes = parseKeyValueAttributes(tokens: tokens)
        return attributes["access"] ?? "internal"
    }

    private func parseInherits(tokens: [ASTToken]) -> String? {
        for (index, token) in tokens.enumerated() {
            switch (token.type, token.value) {
            case (.token, ":"):
                if case .token = tokens[index - 1].type, tokens[index - 1].value == "inherits" {
                    return tokens[index + 1..<tokens.count].map { $0.value }.joined(separator: " ")
                }
            default:
                break
            }
        }
        return nil
    }

    private func isLet(tokens: [ASTToken]) -> Bool {
        return tokens.contains {
            if case .token = $0.type, $0.value == "let" {
                return true
            }
            return false
        }
    }

    private func isImmutable(tokens: [ASTToken]) -> Bool {
        return tokens.contains {
            if case .token = $0.type, $0.value == "immutable" {
                return true
            }
            return false
        }
    }

    private func isImplicit(tokens: [ASTToken]) -> Bool {
        return tokens.contains {
            if case .token = $0.type, $0.value == "implicit" {
                return true
            }
            return false
        }
    }
}
