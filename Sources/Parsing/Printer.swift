/// Declares a type that can incrementally "print" an `Output` value into an `Input` value.
@rethrows public protocol Printer {
  /// The type of values this printer prints into.
  associatedtype Input

  /// The type of values this printer prints.
  associatedtype Output

  /// Attempts to print a well-structured piece of data into something more nebulous.
  ///
  /// - Parameters
  ///   - output: A well-structured value to be printed to the given input.
  ///   - input: A nebulous, mutable piece of data to be incrementally printed to.
  func print(_ output: Output, to input: inout Input) throws
}

extension Printer where Input: AppendableCollection {
  /// Attempts to print a well-structured piece of data to something more nebulous.
  ///
  /// - Parameter output: A well-structured piece of data to be printed.
  /// - Returns: A more nebulous value printed from the given output.
  @inlinable
  public func print(_ output: Output) rethrows -> Input {
    var input = Input()
    try self.print(output, to: &input)
    return input
  }
}

extension Printer where Output == Void {
  /// Attempts to print into a nebulous piece of data.
  ///
  /// - Parameter input: A nebulous, mutable piece of data to be incrementally printed to.
  @inlinable
  public func print(to input: inout Input) rethrows {
    try self.print((), to: &input)
  }
}

extension Printer where Input: AppendableCollection, Output == Void {
  /// Attempts to print a nebulous piece of data.
  ///
  /// - Returns: A nebulous value.
  @inlinable
  public func print() rethrows -> Input {
    try self.print(())
  }
}
