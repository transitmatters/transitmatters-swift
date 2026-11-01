import TransitMattersAPI

/// On-time performance counts for The RIDE or commuter rail over one day, week or month.
///
/// The RIDE entries have ``completed`` and ``onTime``, and ``requests``, ``noShows`` and ``missed`` for
/// periods where every day recorded them. Commuter rail entries have ``otpNumerator``,
/// ``otpDenominator``, ``cancelled``, ``peak`` and ``offPeak``.
public struct Reliability: Sendable, Hashable {
    /// Commuter rail counts for one time period.
    public struct Counts: Sendable, Hashable {
        /// Trips that ran on time.
        public var otpNumerator: Int
        /// Trips measured for on-time performance.
        public var otpDenominator: Int
        public var cancelled: Int

        init(_ counts: Components.Schemas.ReliabilityCounts) {
            otpNumerator = counts.otpNumerator
            otpDenominator = counts.otpDenominator
            cancelled = counts.cancelled
        }
    }

    /// Day, Monday of the week, or first day of the month (`YYYY-MM-DD`).
    public var date: String
    /// Service days with data in the period.
    public var dayCount: Int
    /// The RIDE trips completed.
    public var completed: Int?
    /// The RIDE trips completed on time.
    public var onTime: Int?
    /// The RIDE trip requests.
    public var requests: Int?
    /// The RIDE rider no-shows.
    public var noShows: Int?
    /// The RIDE missed trips.
    public var missed: Int?
    /// Commuter rail trips that ran on time.
    public var otpNumerator: Int?
    /// Commuter rail trips measured for on-time performance.
    public var otpDenominator: Int?
    /// Commuter rail cancelled trips.
    public var cancelled: Int?
    public var peak: Counts?
    public var offPeak: Counts?

    init(_ entry: Components.Schemas.ReliabilityEntry) {
        date = entry.date
        dayCount = entry.days
        completed = entry.completed
        onTime = entry.onTime
        requests = entry.requests
        noShows = entry.noShows
        missed = entry.missed
        otpNumerator = entry.otpNumerator
        otpDenominator = entry.otpDenominator
        cancelled = entry.cancelled
        peak = entry.peak.map(Counts.init)
        offPeak = entry.offPeak.map(Counts.init)
    }
}
