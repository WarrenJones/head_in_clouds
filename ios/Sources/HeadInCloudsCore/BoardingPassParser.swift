import Foundation

public struct ParsedBoardingPass: Equatable, Sendable {
    public let flightNumber: String?
    public let route: String?
    public let departureDate: Date?
    public let confidence: Double

    public init(
        flightNumber: String? = nil,
        route: String? = nil,
        departureDate: Date? = nil,
        confidence: Double = 0
    ) {
        self.flightNumber = flightNumber
        self.route = route
        self.departureDate = departureDate
        self.confidence = confidence
    }
}

public struct BoardingPassTextParser: Sendable {
    public init() {}

    public func parse(_ text: String) -> ParsedBoardingPass {
        let normalized = text
            .uppercased()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)

        let flightNumber: String? = firstMatch(
            in: normalized,
            pattern: #"(?<![A-Z0-9])([A-Z]{2}|[A-Z][0-9]|[0-9][A-Z])\s?([0-9]{3,4})(?![A-Z0-9])"#,
            transform: { groups in
                guard groups.count >= 2 else { return nil }
                return "\(groups[0])\(groups[1])"
            }
        )

        let route: String? = firstMatch(
            in: normalized,
            pattern: #"\b([A-Z]{3})\s*(?:→|->|—|-|TO)\s*([A-Z]{3})\b"#,
            transform: { groups in
                guard groups.count >= 2 else { return nil }
                return "\(groups[0]) → \(groups[1])"
            }
        )

        let departureDate: Date? = firstMatch(
            in: normalized,
            pattern: #"\b(20[0-9]{2})[.\-/](0?[1-9]|1[0-2])[.\-/](0?[1-9]|[12][0-9]|3[01])\b"#,
            transform: { groups in
                guard groups.count >= 3 else { return nil }
                return Self.date(year: groups[0], month: groups[1], day: groups[2])
            }
        )

        let filledFields = [flightNumber != nil, route != nil, departureDate != nil].filter { $0 }.count
        return ParsedBoardingPass(
            flightNumber: flightNumber,
            route: route,
            departureDate: departureDate,
            confidence: Double(filledFields) / 3.0
        )
    }

    private func firstMatch<T>(
        in text: String,
        pattern: String,
        transform: ([String]) -> T?
    ) -> T? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        let groups = (1..<match.numberOfRanges).compactMap { index -> String? in
            let groupRange = match.range(at: index)
            guard groupRange.location != NSNotFound, let range = Range(groupRange, in: text) else {
                return nil
            }
            return String(text[range])
        }

        return transform(groups)
    }

    private static func date(year: String, month: String, day: String) -> Date? {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = Int(year)
        components.month = Int(month)
        components.day = Int(day)
        return components.date
    }
}
