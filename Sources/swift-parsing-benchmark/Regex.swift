import Benchmark
import Foundation
import Parsing

#if canImport(RegexBuilder)
  import RegexBuilder
#endif

let regexSuite = BenchmarkSuite(name: "Regex") { suite in

  let input = """
    Platform        JOIN DATE        NAME
    ===================================
    iOS         03/02/2018      Ruben Sissing
    Android     06/01/2022      Samuel Oyedele
    iOS         11/11/2020      Hadi Dbouk.
    iOS         03/02/2023      Ada Jiang
    """

  enum Platform: String, CaseIterable {
    case iOS
    case android = "Android"
  }

  struct Person {
    let platform: Platform
    let date: DateComponents
    let name: String
  }

  #if swift(>=5.7) && canImport(RegexBuilder)
    let platform = Regex {
      TryCapture {
        ChoiceOf {
          "iOS"
          "Android"
        }
      } transform: {
        Platform(rawValue: String($0))
      }
    }

    let date = Regex {
      Capture {
        .date(.numeric, locale: .current, timeZone: .gmt)
      } transform: {
        Calendar.current.dateComponents([.year, .month, .day], from: $0)
      }
    }

    let name = Regex {
      Capture {
        OneOrMore {
          .any.subtracting(.newlineSequence)
        }
      } transform: {
        String($0)
      }
    }

    let personRegex = Regex {
      platform
      OneOrMore(.whitespace)
      date
      OneOrMore(.whitespace)
      name
    }

    suite.benchmark("Regex") {
      let persons = input.matches(of: personRegex).map {
        Person(platform: $0.1, date: $0.2, name: $0.3)
      }
      assert(persons.count == 4)
    }
  #endif

  let dateParser = ParsePrint(
    .convert(
      apply: { month, day, year in DateComponents(year: year, month: month, day: day) },
      unapply: { dateComponents in
        guard
          let month = dateComponents.month,
          let day = dateComponents.day,
          let year = dateComponents.year
        else { return nil }
        return (month, day, year)
      }
    )
  ) {
    Digits(2)
    "/"
    Digits(2)
    "/"
    Digits(4)
  }

  let personParser = ParsePrint(.memberwise(Person.init)) {
    Platform.parser()
    Whitespace(1...)
    dateParser
    Whitespace(1...)
    OneOf {
      PrefixUpTo("\n")
      Rest()
    }.map(.string)
  }

  let personsParser = Parse {
    Skip {
      PrefixThrough("=\n")
    }
    Many {
      personParser
    } separator: {
      "\n"
    }
  }

  suite.benchmark("Parsing") {
    let persons = try personsParser.parse(input[...])
    assert(persons.count == 4)
  }

}
