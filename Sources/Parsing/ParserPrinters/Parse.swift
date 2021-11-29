public struct Parse<Upstream> {
  public let upstream: Upstream

  @inlinable
  public init(@ParserBuilder _ build: () -> Upstream) {
    self.upstream = build()
  }
}

extension Parse: Parser where Upstream: Parser {
  @inlinable
  public func parse(_ input: inout Upstream.Input) -> Upstream.Output? {
    self.upstream.parse(&input)
  }
}

extension Parse: Printer where Upstream: Printer {
  @inlinable
  public func print(_ output: Upstream.Output) -> Upstream.Input? {
    self.upstream.print(output)
  }
}
