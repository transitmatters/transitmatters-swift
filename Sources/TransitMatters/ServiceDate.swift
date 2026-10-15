import Foundation

/// A calendar day, as the API's `YYYY-MM-DD` date parameters expect.
///
/// A day rather than a `Date`, so a request can't silently shift to the neighboring day
/// because of the time zone it was made in.
public struct ServiceDate: Hashable, Comparable, Sendable, LosslessStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar`, which defaults to the user's calendar and time zone.
    public init(_ date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year!, month: components.month!, day: components.day!)
    }

    /// Parses a `YYYY-MM-DD` string.
    public init?(_ description: String) {
        let parts = description.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The `YYYY-MM-DD` form the API uses.
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: ServiceDate, rhs: ServiceDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
