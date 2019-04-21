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

public struct AST {
    public let declarations: [Declaration]
}

public enum Statement {
    case expression(Expression)
    case declaration(Declaration)
}

public struct Expression {
    public let identifier = UUID()
    public let rawValue: String
    // FIXME: Remove optionals
    public let type: String!
    public let rawLocation: String!
    public let rawRange: String!
    public let location: SourceLocation!
    public let range: SourceRange!
    public let decl: String?
    public let value: String?
    public let throwsModifier: String?
    public let argumentLabels: String?
    public let isImplicit: Bool
    public var expressions = [Expression]()
}

extension Expression: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    public static func ==(lhs: Expression, rhs: Expression) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

public enum Declaration {
    case `topLevelCode`(TopLevelCodeDeclaration)
    case `import`(ImportDeclaration)
    case `struct`(StructDeclaration)
    case `class`(ClassDeclaration)
    case `enum`(EnumDeclaration)
    case `extension`(ExtensionDeclaration)
    case variable(VariableDeclaration)
    case function(FunctionDeclaration)
}

public struct TopLevelCodeDeclaration {
    public let statements: [Statement]
}

public struct ImportDeclaration {
    public let importKind: String?
    public let importPath: String
}

public struct StructDeclaration {
    public let accessLevel: String
    public let name: String
    public let typeInheritance: String?
    public let members: [StructMember]
}

public enum StructMember {
    case declaration(Declaration)
}

public struct ClassDeclaration {
    public let accessLevel: String
    public let name: String
    public let typeInheritance: String?
    public let members: [ClassMember]
}

public enum ClassMember {
    case declaration(Declaration)
}

public struct EnumDeclaration {
    public let accessLevel: String
    public let name: String
    public let typeInheritance: String?
    public let members: [EnumMember]
}

public enum EnumMember {
    case declaration(Declaration)
}

public struct ExtensionDeclaration {
    public let accessLevel: String
    public let name: String
    public let typeInheritance: String?
    public let members: [ExtensionMember]
}

public enum ExtensionMember {
    case declaration(Declaration)
}

public struct VariableDeclaration {
    public let accessLevel: String
    public let isLet: Bool
    public let name: String
    public let type: String
    public let isImmutable: Bool
}

public struct FunctionDeclaration {
    public let accessLevel: String
    public let name: String
    public let parameters: [Parameter]
    public let body: [Statement]
}

public struct Parameter {
    public let externalName: String?
    public let localName: String
    public let type: String
}

public struct FunctionResult {
    public let type: String
}

public struct SourceRange {
    public let start: SourceLocation
    public let end: SourceLocation
}

extension SourceRange: Hashable {
    public static let zero = SourceRange(start: .zero, end: .zero)

    public func hash(into hasher: inout Hasher) {
        hasher.combine(start)
        hasher.combine(end)
    }

    public static func ==(lhs: SourceRange, rhs: SourceRange) -> Bool {
        return lhs.start == rhs.start && lhs.end == rhs.end
    }
}

extension SourceRange: CustomStringConvertible {
    public var description: String {
        return "\(start)-\(end)"
    }
}

public struct SourceLocation {
    public let line: Int
    public let column: Int
    public static let zero = SourceLocation(line: 0, column: 0)
}

extension SourceLocation: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(line)
        hasher.combine(column)
    }

    public static func ==(lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        return lhs.line == rhs.line && lhs.column == rhs.column
    }
}

extension SourceLocation: Comparable {
    public static func <(lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        if lhs.line != rhs.line {
            return lhs.line < rhs.line
        }
        return lhs.column < rhs.column
    }
}

extension SourceLocation: CustomStringConvertible {
    public var description: String {
        return "\(line):\(column)"
    }
}
