import TransitMattersAPI

/// Commuter Rail fleet makeup for a route over one aggregation period.
public struct CommuterRailTripMetrics: Sendable, Hashable {
    /// Day, Monday of the week, or first day of the month (`YYYY-MM-DD`).
    public var date: String
    /// The route ID, or `all`.
    public var route: String
    /// Trips with a known cab car, which the fleet figures are based on.
    public var fleetTrips: Double?
    public var averageCabCarAge: Double?
    /// Percentage of fleet trips by fleet, keyed by fleet (`rotem`, `kawasaki`, `bombardier`, `mbb`, `locomotive`).
    public var fleetMix: [String: Double]

    init(_ entry: Components.Schemas.CrTripMetricsEntry) {
        date = entry.date
        route = entry.route
        fleetTrips = entry.fleet_trips
        averageCabCarAge = entry.additionalProperties.number("avg_cab_car_age")
        fleetMix = entry.additionalProperties.numbers(prefix: "fleet_mix_")
    }
}

/// A Commuter Rail schedule measured against Regional Rail standards, averaged over ``dayCount`` days.
public struct CommuterRailScorecard: Sendable, Hashable {
    /// Which schedule to measure.
    public enum DayKind: String, Sendable, Hashable, CaseIterable {
        case weekday
        case saturday
        case sunday
        /// Every day mixed together.
        case all
    }

    /// Scheduled service in one direction, measured at the Boston terminal.
    public struct Direction: Sendable, Hashable {
        public var trips: Double?
        /// First train, in seconds after midnight.
        public var firstTripSeconds: Double?
        /// Last train, in seconds after midnight.
        public var lastTripSeconds: Double?
        /// Longest midday wait, in minutes.
        public var longestMiddayGapMinutes: Double?
        /// Longest evening wait, in minutes.
        public var longestEveningGapMinutes: Double?
        /// Hours from 5am to 1am with a train at least every 30 minutes.
        public var hoursAtTarget: Double?
        /// Share of trains on a repeating hourly pattern, from 0 to 1.
        public var clockFaceShare: Double?
        /// Trains in each hour of the day, starting at midnight.
        public var tripsByHour: [Double?]?

        init(_ direction: Components.Schemas.CrScorecardDirection) {
            trips = direction.trips
            firstTripSeconds = direction.firstTrip
            lastTripSeconds = direction.lastTrip
            longestMiddayGapMinutes = direction.maxGapMidday
            longestEveningGapMinutes = direction.maxGapEvening
            hoursAtTarget = direction.hoursAtTarget
            clockFaceShare = direction.clockFaceShare
            tripsByHour = direction.byHour
        }
    }

    /// Day, Monday of the week, or first day of the month (`YYYY-MM-DD`). `nil` for the
    /// `commuter-rail` summary.
    public var date: String?
    /// The route ID, for the `commuter-rail` summary. `nil` for a single route.
    public var routeID: String?
    /// Days averaged.
    public var dayCount: Int
    public var outbound: Direction
    public var inbound: Direction
    /// Peak trains, both directions.
    public var peakTrips: Double?
    /// Reverse-peak trains, both directions.
    public var reversePeakTrips: Double?

    init(_ entry: Components.Schemas.CrScorecardEntry) {
        date = entry.date
        routeID = entry.routeId
        dayCount = entry.days
        outbound = Direction(entry.outbound)
        inbound = Direction(entry.inbound)
        peakTrips = entry.peakTrips
        reversePeakTrips = entry.reversePeakTrips
    }
}
