import Parsing

var input = ""[...]

protocol AppendableCollection: Collection {
  mutating func append<S>(contentsOf newElements: S) where S : Sequence, Self.Element == S.Element
}

import Foundation

extension Substring: AppendableCollection {}
extension ArraySlice: AppendableCollection {}
extension Data: AppendableCollection {}
extension Substring.UnicodeScalarView: AppendableCollection {}

extension Substring.UTF8View: AppendableCollection {
  mutating func append<S>(contentsOf newElements: S) where S : Sequence, String.UTF8View.Element == S.Element {
    var result = Substring(self)
    switch newElements {
    case let newElements as Substring.UTF8View:
      result.append(contentsOf: Substring(newElements))
    default:
      result.append(contentsOf: Substring(decoding: Array(newElements), as: UTF8.self))
    }
    self = result.utf8
  }
}

//let _quotedField = ParsePrint {
//  "\"".utf8
//  Prefix { $0 != .init(ascii: "\"") }
//  "\"".utf8
//}


protocol Printer {
  associatedtype Input
  associatedtype Output
  func print(_ output: Output, to input: inout Input) throws
}

extension String: Printer {
  func print(_ output: (), to input: inout Substring) {
    input.append(contentsOf: self)
  }
}

extension String.UTF8View: Printer {
  func print(_ output: (), to input: inout Substring.UTF8View) {
    input.append(contentsOf: self)
  }
}

struct PrintingError: Error {}

extension Prefix: Printer where Input: AppendableCollection {
  func print(_ output: Input, to input: inout Input) throws {
    guard output.allSatisfy(self.predicate!)
    else { throw PrintingError() }

    input.append(contentsOf: output)
  }
}

extension Parse: Printer where Parsers: Printer {
  func print(_ output: Parsers.Output, to input: inout Parsers.Input) throws {
    try self.parsers.print(output, to: &input)
  }
}

extension Parsers.ZipVOV: Printer
where P0: Printer, P1: Printer, P2: Printer
{
  func print(
    _ output: P1.Output,
    to input: inout P0.Input
  ) throws {
    try self.p0.print((), to: &input)
    try self.p1.print(output, to: &input)
    try self.p2.print((), to: &input)
  }
}

typealias ParsePrint<P: Parser & Printer> = Parse<P>

extension OneOf: Printer where Parsers: Printer {
  func print(_ output: Parsers.Output, to input: inout Parsers.Input) throws {
    try self.parsers.print(output, to: &input)
  }
}

extension Parsers.OneOf2: Printer where P0: Printer, P1: Printer {
  func print(_ output: P0.Output, to input: inout P0.Input) throws {
    let original = input
    do {
      try self.p1.print(output, to: &input)
    } catch {
      input = original
      try self.p0.print(output, to: &input)
    }
  }
}

extension Skip: Printer where Parsers: Printer, Parsers.Output == Void {
  func print(
    _ output: (),
    to input: inout Parsers.Input
  ) throws {
    try self.parsers.print((), to: &input)
  }
}

extension Parsers.ZipVV: Printer where P0: Printer, P1: Printer {
  func print(_ output: (), to input: inout P0.Input) throws {
    try self.p0.print((), to: &input)
    try self.p1.print((), to: &input)
  }
}

extension Parsers.IntParser: Printer where Input: AppendableCollection {
  func print(_ output: Output, to input: inout Input) {
//    var substring = Substring(input)
//    substring.append(contentsOf: String(output))
//    input = substring.utf8
    input.append(contentsOf: String(output).utf8)
  }
}

extension FromUTF8View: Printer where UTF8Parser: Printer {
  func print(
    _ output: UTF8Parser.Output,
    to input: inout Input
  ) throws {
    var utf8 = self.toUTF8(input)
    defer { input = self.fromUTF8(utf8) }
    try self.utf8Parser.print(output, to: &utf8)
  }
}

extension Parsers.BoolParser: Printer where Input: AppendableCollection {
  func print(
    _ output: Bool,
    to input: inout Input
  ) throws {
    input.append(contentsOf: String(output).utf8)
  }
}

extension Parsers.ZipOVOVO: Printer
where
  P0: Printer,
  P1: Printer,
  P2: Printer,
  P3: Printer,
  P4: Printer
{
  func print(_ output: (P0.Output, P2.Output, P4.Output), to input: inout P0.Input) throws {
    try self.p0.print(output.0, to: &input)
    try self.p1.print((), to: &input)
    try self.p2.print(output.1, to: &input)
    try self.p3.print((), to: &input)
    try self.p4.print(output.2, to: &input)
  }
}

extension Many: Printer
where
  Element: Printer,
  Separator: Printer,
  Separator.Output == Void,
  Result == [Element.Output]
{
  func print(_ output: [Element.Output], to input: inout Element.Input) throws {
    var firstElement = true
    for elementOutput in output {
      defer { firstElement = false }
      if !firstElement {
        try self.separator.print((), to: &input)
      }
      try self.element.print(elementOutput, to: &input)
    }
  }
}

try Parse
{
  "Hello "
  FromUTF8View { Int.parser() }
  "!"
}
.parse("Hello 42!")

input = ""
try Parse { "Hello "; Int.parser(); "!" }
.print(42, to: &input)
input

//Skip { Prefix { $0 != "," } }.print(<#T##output: ()##()#>, to: &<#T##_#>)


// f: (A) -> B

// parse: (inout Input) throws -> Output
// print: (Output, inout Input) throws -> Void

//extension Parsers.Map: Printer where Upstream: Printer {
//  func print(_ output: NewOutput, to input: inout Upstream.Input) throws {
//    self.transform
//    self.upstream.print(<#T##output: Upstream.Output##Upstream.Output#>, to: &<#T##Upstream.Input#>)
//  }
//}

typealias ParserPrinter = Parser & Printer

struct Conversion<A, B> {
  let apply: (A) -> B
  let unapply: (B) -> A
}

extension Conversion where A == Substring, B == String {
  static let string = Self(
    apply: { String($0) },
    unapply: { Substring($0) }
  )
}

extension Parser where Self: Printer {
  func map<NewOutput>(
    _ conversion: Conversion<Output, NewOutput>
  ) -> Parsers.InvertibleMap<Self, NewOutput> {
    .init(upstream: self, transform: conversion.apply, untransform: conversion.unapply)
  }
}

// map: ((A) -> B) -> (F<A>) -> F<B>
// map: ((A) -> B) -> (Array<A>) -> Array<B>
// map: ((A) -> B) -> (Optional<A>) -> Optional<B>
// map: ((A) -> B) -> (Result<A, _>) -> Result<B, _>
// map: ((A) -> B) -> (Dictionary<_, A>) -> Dictionary<_, B>
//...
// map: (Conversion<A, B>) -> (ParserPrinter<_, A>) -> ParserPrinter<_, B>

// pullback: (KeyPath<A, B>) -> (Reducer<B, _, _>) -> Reducer<A, _, _>
// pullback: (CasePath<A, B>) -> (Reducer<_, B, _>) -> Reducer<_, A, _>


extension Parsers {
  struct InvertibleMap<Upstream: ParserPrinter, NewOutput>: ParserPrinter {
    let upstream: Upstream
    let transform: (Upstream.Output) -> NewOutput
    let untransform: (NewOutput) -> Upstream.Output

    func parse(_ input: inout Upstream.Input) throws -> NewOutput {
      try self.transform(self.upstream.parse(&input))
    }

    func print(_ output: NewOutput, to input: inout Upstream.Input) throws {
      try self.upstream.print(self.untransform(output), to: &input)
    }
  }
}

extension Parse {
  init<Upstream, NewOutput>(
    _ conversion: Conversion<Upstream.Output, NewOutput>,
    @ParserBuilder with build: () -> Upstream
  ) where Parsers == Parsing.Parsers.InvertibleMap<Upstream, NewOutput> {
    self.init { build().map(conversion) }
  }
}

extension Parsers.ZipOVO: Printer where P0: Printer, P1: Printer, P2: Printer {
  func print(_ output: (P0.Output, P2.Output), to input: inout P0.Input) throws {
    try self.p0.print(output.0, to: &input)
    try self.p1.print((), to: &input)
    try self.p2.print(output.1, to: &input)
  }
}

input = ""
try Parse {
  Prefix { $0 != "\"" }
}
.print("Blob, Esq.", to: &input)
input

try Prefix
{ $0 != "\"" }.parse(&input)

input = ""
"Hello".print((), to: &input)
try "Hello".parse(&input) // ()

//print(<#T##items: Any...##Any#>, to: &<#T##TextOutputStream#>)

// parse: (inout Input) throws -> Output

// parse: (Input) throws -> (Output, Input)
// print: (Output, Input) throws -> Input

// print: (Output, inout Input) throws -> Void

// (S) -> (S, A)
// (inout S) -> A

let usersCsv = """
1, Blob, true
2, Blob Jr, false
3, Blob Sr, true
4, "Blob, Esq.", true
"""

struct User: Equatable {
  var id: Int
  var name: String
  var admin: Bool
}

//OneOf {
//  a.map(f)
//  b.map(f)
//  c.map(f)
//}
//==
//OneOf {
//  a
//  b
//  c
//}
//.map(f)

let quotedFieldUtf8 = ParsePrint {
  "\"".utf8
  Prefix { $0 != .init(ascii: "\"") }
  "\"".utf8
}
var inputUtf8 = ""[...].utf8
try quotedFieldUtf8.print("Blob, Esq"[...].utf8, to: &inputUtf8)
Substring(inputUtf8)

let quotedField = ParsePrint {
  "\""
  Prefix { $0 != "\"" }
  "\""
}

input = ""
try quotedField.print("Blob, Esq.", to: &input)
input
let parsedQuotedField = try quotedField.parse(&input)
try quotedField.print(parsedQuotedField, to: &input)
input

let fieldUtf8 = OneOf {
  quotedFieldUtf8

  Prefix { $0 != .init(ascii: ",") }
}
//  .map { String(Substring($0)) }

let field = OneOf {
  quotedField

  Prefix { $0 != "," }
}
.map(.string)

input = ""
try field.print("Blob, Esq." as String, to: &input)
input

input = ""
try field.print("Blob Jr." as String, to: &input)
input

let zeroOrOneSpaceUtf8 = OneOf {
  " ".utf8
  "".utf8
}

let zeroOrOneSpace = OneOf {
  " "
  ""
}

input = ""
try Skip {
  ","
  zeroOrOneSpace
}
.print((), to: &input)
input

let userUtf8 = Parse {
  Int.parser()
  Skip {
    ",".utf8
    zeroOrOneSpaceUtf8
  }
  fieldUtf8
  Skip {
    ",".utf8
    zeroOrOneSpaceUtf8
  }
  Bool.parser()
}

unsafeBitCast((1, "Blob", true), to: User.self)
unsafeBitCast(User(id: 1, name: "Blob", admin: true), to: (Int, String, Bool).self)


struct Private {
  private let value: Int
//  private let other: Int = 1
  private init(value: Int) {
    self.value = value
  }
}

//Never

//Private(value: 42)
let `private` = unsafeBitCast(42, to: Private.self)
unsafeBitCast(`private`, to: Int.self)

extension Conversion where A == (Int, String, Bool), B == User {
  static let user = Self(
    apply: B.init,
    unapply: { unsafeBitCast($0, to: A.self) }
  )
}

extension Conversion {
  static func `struct`(_ `init`: @escaping (A) -> B) -> Self {
    Self(
      apply: `init`,
      unapply: { unsafeBitCast($0, to: A.self) }
    )
  }
}


struct Person {
  let firstName, lastName: String
  var bio: String = ""

  init(lastName: String, firstName: String) {
    self.firstName = firstName
    self.lastName = lastName
  }
}

MemoryLayout<(String, String)>.size
MemoryLayout<Person>.size

let person = ParsePrint(.struct(Person.init)) {
  Prefix { $0 != " " }.map(.string)
  " "
  Prefix { $0 != " " }.map(.string)
}

input = "Blob McBlob"
let p = try person.parse(&input)
input
try person.print(p, to: &input)
input


let user = ParsePrint(.struct(User.init)) {
  Int.parser()
  Skip {
    ","
    zeroOrOneSpace
  }
  field
  Skip {
    ","
    zeroOrOneSpace
  }
  Bool.parser()
}
//.map(User.init)
//.map(.struct(User.init))

input = ""
try user.print(User(id: 42, name: "Blob, Esq.", admin: true), to: &input)
input

let usersUtf8 = Many {
  userUtf8
} separator: {
  "\n".utf8
} terminator: {
  End()
}

let users = Many {
  user
} separator: {
  "\n"
} terminator: {
  End()
}

inputUtf8 = ""[...].utf8
try usersUtf8.print([
  (1, "Blob"[...].utf8, true),
  (2, "Blob, Esq."[...].utf8, false),
], to: &inputUtf8)
Substring(inputUtf8)

input = ""
try users.print([
  User(id: 1, name: "Blob", admin: true),
  User(id: 2, name: "Blob, Esq.", admin: false),
], to: &input)
input

input = "A,A,A,B"
try Many { "A" } separator: { "," }.parse(&input)
input

input = usersCsv[...]
let output = try users.parse(&input)
input

"，" == ","

func print(user: User) -> String {
  "\(user.id), \(user.name.contains(",") ? "\"\(user.name)\"" : "\(user.name)"), \(user.admin)"
}
struct UserPrinter: Printer {
  func print(_ user: User, to input: inout String) {
    input.append(contentsOf: "\(user.id),")
    if user.name.contains(",") {
      input.append(contentsOf: "\"\(user.name)\"")
    } else {
      input.append(contentsOf: user.name)
    }
    input.append(contentsOf: ",\(user.admin)")
  }
}

print(user: .init(id: 42, name: "Blob", admin: true))

func print(users: [User]) -> String {
  users.map(print(user:)).joined(separator: "\n")
}
struct UsersPrinter: Printer {
  func print(_ users: [User], to input: inout String) {
    var firstElement = true
    for user in users {
      defer { firstElement = false }
      if !firstElement {
        input += "\n"
      }
      UserPrinter().print(user, to: &input)
    }
  }
}

input = ""
//users.print(output, to: &input)

//print(users: output)
//
//input = usersCsv[...]
//try print(users: users.parse(input)) == input
//try users.parse(print(users: output)) == output
//
//var inputString = ""
//UsersPrinter().print(output, to: &inputString)
//inputString




"🇺🇸".count
"🇺🇸".unicodeScalars.count
Array("🇺🇸".unicodeScalars)
String.UnicodeScalarView([.init(127482)!])
String.UnicodeScalarView([.init(127480)!])

"🇺🇸".utf8.count
Array("🇺🇸".utf8)

String(decoding: [240, 159, 135, 186, 240, 159, 135, 184], as: UTF8.self)
String(decoding: [240, 159, 135, 186], as: UTF8.self)
String(decoding: [240, 159, 135, 184], as: UTF8.self)

String(decoding: [240, 159], as: UTF8.self)
String(decoding: [135, 186, 240, 159, 135, 184], as: UTF8.self)

var utf8 = "🇺🇸".utf8
//utf8.replaceSubrange(0...0, with: [241])
