import TransitMattersAPI

/// Trip counts, time, distance and fleet makeup for a bus route over one aggregation period.
public struct BusTripMetrics: Sendable, Hashable {
    /// A part of the service day.
    public enum TimeBand: String, Sendable, Hashable, CaseIterable {
        case earlyMorning = "early_am"
        case amPeak = "am_peak"
        case midday
        case pmPeak = "pm_peak"
        case evening
        case lateNight = "late_night"
    }

    /// Which days to include.
    public enum DayType: String, Sendable, Hashable, CaseIterable {
        case businessDay = "business_day"
        /// Weekends and MBTA holidays.
        case weekendOrHoliday = "weekend_or_holiday"
    }

    /// Day, Monday of the week, or first day of the month (`YYYY-MM-DD`).
    public var date: String
    /// The route ID, or the comma-separated group that was requested.
    public var route: String
    public var count: Double
    /// Total trip time, in seconds.
    public var totalTime: Double
    public var milesCovered: Double
    /// Segment traversals measured.
    public var traversalCount: Double
    /// Only on daily entries for the whole day.
    public var medianSpeedMph: Double?
    /// Only on daily entries for the whole day.
    public var meanSpeedMph: Double?
    /// Trips with a known bus, which the fleet figures are based on.
    public var fleetTrips: Double?
    public var averageBusAge: Double?
    /// Percentage of fleet trips by propulsion type, keyed by type (`hybrid`, `cng`, `diesel`, `battery`).
    public var fleetMix: [String: Double]
    /// Percentage of trips run with each type of bus, keyed by type (`battery`).
    public var percentTripsByType: [String: Double]

    /// Distance over time, in mph. `nil` when no trip time was recorded.
    public var averageSpeedMph: Double? {
        totalTime > 0 ? milesCovered / (totalTime / 3600) : nil
    }

    init(_ entry: Components.Schemas.BusTripMetricsEntry) {
        let extra = entry.additionalProperties
        date = entry.date
        route = entry.route
        count = entry.count
        totalTime = entry.total_time
        milesCovered = entry.miles_covered
        traversalCount = entry.n_traversals
        medianSpeedMph = extra.number("median_speed_mph")
        meanSpeedMph = extra.number("mean_speed_mph")
        fleetTrips = extra.number("fleet_trips")
        averageBusAge = extra.number("avg_bus_age")
        fleetMix = extra.numbers(prefix: "fleet_mix_")
        percentTripsByType = extra.numbers(prefix: "pct_", suffix: "_trips")
    }
}

/// A bus route's trip totals over a date range, for ranking routes by speed.
public struct BusRouteSpeed: Sendable, Hashable {
    public var route: String
    public var count: Double
    /// Total trip time, in seconds.
    public var totalTime: Double
    public var milesCovered: Double
    /// Segment traversals measured.
    public var traversalCount: Double

    /// Distance over time, in mph. `nil` when no trip time was recorded.
    public var averageSpeedMph: Double? {
        totalTime > 0 ? milesCovered / (totalTime / 3600) : nil
    }

    init(_ entry: Components.Schemas.BusSpeedLeaderboardEntry) {
        route = entry.route
        count = entry.count
        totalTime = entry.total_time
        milesCovered = entry.miles_covered
        traversalCount = entry.n_traversals
    }
}
