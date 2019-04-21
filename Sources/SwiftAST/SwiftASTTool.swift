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
import Utility
import POSIX

struct SwiftASTTool {
    let parser: ArgumentParser
    let options: Options

    init(arguments: [String]) {
        parser = ArgumentParser(commandName: "swift-ast", usage: "[options] subcommand [options]", overview: "")

        let binder = ArgumentBinder<Options>()
        binder.bind(parser: parser) { $0.subcommand = $1 }
        binder.bind(option: parser.add(option: "--version", kind: Bool.self)) { (options, _) in options.subcommand = "version" }
        binder.bind(option: parser.add(option: "--verbose", kind: Bool.self, usage: "")) { $0.verbose = $1 }

        let parse = parser.add(subparser: "parse", overview: "")
        binder.bind(positional: parse.add(positional: "source", kind: String.self), to: { $0.source = $1 })
        binder.bindArray(option: parse.add(option: "-buildCommand", kind: [String].self, strategy: .remaining, usage: "")) { $0.buildCommand = $1 }

        do {
            let result = try parser.parse(arguments)
            var options = Options()
            try binder.fill(parseResult: result, into: &options)
            self.options = options
        } catch {
            handle(error: error)
            POSIX.exit(1)
        }
    }
}

struct Options {
    var verbose = false
    var subcommand = ""

    var source = ""
    var buildCommand = [String]()
}
