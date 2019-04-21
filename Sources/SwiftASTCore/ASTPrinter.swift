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
import Basic

public struct ASTPrinter {
    let sourceFile: SourceFile
    private let fileSystem = Basic.localFileSystem

    public init(sourceFile: URL) {
        let contents = try! fileSystem.readFileContents(AbsolutePath(sourceFile.path))
        let sourceText = contents.asReadableString

        var lineNumber = 1
        var offset = 0
        var sourceLines = [SourceLine]()
        for line in sourceText.split(separator: "\n", omittingEmptySubsequences: false) {
            sourceLines.append(SourceLine(text: String(line).utf8, lineNumber: lineNumber, offset: offset))
            lineNumber += 1
            offset += line.utf8.count + 1 // characters + newline
        }
        self.sourceFile = SourceFile(sourceText: sourceText.utf8, sourceLines: sourceLines)
    }
    
    public func print(_ root: AST) {
        for declaration in root.declarations {
            print(declaration)
        }
    }

    public func print(_ declaration: Declaration) {
        switch declaration {
        case .topLevelCode(let declaration):
            print(declaration)
        case .import(let declaration):
            print(declaration)
        case .struct(let declaration):
            print(declaration)
        case .class(let declaration):
            print(declaration)
        case .enum(let declaration):
            print(declaration)
        case .extension(let declaration):
            print(declaration)
        case .variable(let declaration):
            print(declaration)
        case .function(let declaration):
            print(declaration)
        }
    }

    public func print(_ expression: Expression) {
        if let range = expression.range {
            let source = sourceFile[range]
            Swift.print("[\(expression.rawValue) (\(range))] \(source)")
        }

        for expression in expression.expressions {
            print(expression)
        }
    }

    public func print(_ statement: Statement) {
        switch statement {
        case .expression(let expression):
            print(expression)
        case .declaration(let declaration):
            print(declaration)
        }
    }

    public func print(_ declaration: TopLevelCodeDeclaration) {
        for statement in declaration.statements {
            switch statement {
            case .expression(let expression):
                print(expression)
            case .declaration(let declaration):
                print(declaration)
            }
        }
    }

    public func print(_ declaration: ImportDeclaration) {
        if let importKind = declaration.importKind {
            Swift.print("import \(importKind) \(declaration.importPath)")
        } else {
            Swift.print("import \(declaration.importPath)")
        }
    }

    public func print(_ declaration: StructDeclaration) {
        if let typeInheritance = declaration.typeInheritance {
            Swift.print("\(declaration.accessLevel) struct \(declaration.name): \(typeInheritance) {")
        } else {
            Swift.print("\(declaration.accessLevel) struct \(declaration.name) {")
        }
        for member in declaration.members {
            switch member {
            case .declaration(let declaration):
                print(declaration)
            }
        }
        Swift.print("}")
    }

    public func print(_ declaration: ClassDeclaration) {
        if let typeInheritance = declaration.typeInheritance {
            Swift.print("\(declaration.accessLevel) class \(declaration.name): \(typeInheritance) {")
        } else {
            Swift.print("\(declaration.accessLevel) class \(declaration.name) {")
        }
        for member in declaration.members {
            switch member {
            case .declaration(let declaration):
                print(declaration)
            }
        }
        Swift.print("}")
    }

    public func print(_ declaration: EnumDeclaration) {
        if let typeInheritance = declaration.typeInheritance {
            Swift.print("\(declaration.accessLevel) enum \(declaration.name): \(typeInheritance) {")
        } else {
            Swift.print("\(declaration.accessLevel) enum \(declaration.name) {")
        }
        for member in declaration.members {
            switch member {
            case .declaration(let declaration):
                print(declaration)
            }
        }
        Swift.print("}")
    }

    public func print(_ declaration: ExtensionDeclaration) {
        if let typeInheritance = declaration.typeInheritance {
            Swift.print("\(declaration.accessLevel) extension \(declaration.name): \(typeInheritance) {")
        } else {
            Swift.print("\(declaration.accessLevel) extension \(declaration.name) {")
        }
        for member in declaration.members {
            switch member {
            case .declaration(let declaration):
                print(declaration)
            }
        }
        Swift.print("}")
    }

    public func print(_ declaration: VariableDeclaration) {
        Swift.print("\(declaration.accessLevel) \(declaration.isLet ? "let" : "\(declaration.isImmutable ? "immutable " : " ")var") \(declaration.name): \(declaration.type) \(declaration.isImmutable ? "{ get }" : "{ get set }")")
    }

    public func print(_ declaration: FunctionDeclaration) {
        var parmeters = ""
        for parameter in declaration.parameters {
            if let externalName = parameter.externalName {
                parmeters += "\(externalName) \(parameter.localName)"
            } else {
                parmeters += "\(parameter.localName)"
            }
            parmeters += ": \(parameter.type), "
        }
        Swift.print("\(declaration.accessLevel) func \(declaration.name)(\(parmeters)) {")

        for statement in declaration.body {
            print(statement)
        }

        Swift.print("}")
    }
}
