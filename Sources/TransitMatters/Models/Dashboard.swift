import TransitMattersAPI

/// Combined service and ridership data for the overview dashboard.
public struct ServiceRidershipDashboard: Sendable, Hashable {
    public var summary: Summary
    /// Summaries keyed by mode.
    public var modes: [String: Summary]
    /// Lines keyed by line ID.
    public var lines: [String: Line]

    init(_ response: Components.Schemas.ServiceRidershipDashboardResponse) {
        summary = Summary(response.summaryData)
        modes = response.modeData.additionalProperties.mapValues(Summary.init)
        lines = response.lineData.additionalProperties.mapValues(Line.init)
    }
}

extension ServiceRidershipDashboard {
    public struct Summary: Sendable, Hashable {
        /// Ridership keyed by date.
        public var ridershipHistory: [String: Double]
        /// Service keyed by date.
        public var serviceHistory: [String: Double]
        public var ridershipPercentage: Double
        public var servicePercentage: Double
        public var passengers: Double
        public var trips: Double
        public var routesCancelled: Int
        public var reducedService: Int
        public var increasedService: Int
        public var startDate: String
        public var endDate: String

        init(_ summary: Components.Schemas.DashboardSummary) {
            ridershipHistory = summary.totalRidershipHistory?.additionalProperties ?? [:]
            serviceHistory = summary.totalServiceHistory?.additionalProperties ?? [:]
            ridershipPercentage = summary.totalRidershipPercentage
            servicePercentage = summary.totalServicePercentage
            passengers = summary.totalPassengers
            trips = summary.totalTrips
            routesCancelled = summary.totalRoutesCancelled
            reducedService = summary.totalReducedService
            increasedService = summary.totalIncreasedService
            startDate = summary.startDate
            endDate = summary.endDate
        }
    }

    public struct Line: Sendable, Hashable, Identifiable {
        public var id: String
        public var shortName: String
        public var longName: String
        public var routeIDs: [String]
        public var startDate: String
        public var lineKind: String
        /// Ridership keyed by date.
        public var ridershipHistory: [String: Double]
        /// Service keyed by date.
        public var serviceHistory: [String: Double]
        public var serviceRegimes: ServiceRegimes

        init(_ line: Components.Schemas.DashboardLine) {
            id = line.id
            shortName = line.shortName
            longName = line.longName
            routeIDs = line.routeIds
            startDate = line.startDate
            lineKind = line.lineKind
            ridershipHistory = line.ridershipHistory?.additionalProperties ?? [:]
            serviceHistory = line.serviceHistory?.additionalProperties ?? [:]
            serviceRegimes = ServiceRegimes(line.serviceRegimes)
        }
    }

    /// A line's service now, a year ago, and at its baseline.
    public struct ServiceRegimes: Sendable, Hashable {
        public var current: ServiceRegime
        public var oneYearAgo: ServiceRegime
        public var baseline: ServiceRegime

        init(_ regimes: Components.Schemas.DashboardServiceRegimes) {
            current = ServiceRegime(regimes.current)
            oneYearAgo = ServiceRegime(regimes.oneYearAgo)
            baseline = ServiceRegime(regimes.baseline)
        }
    }

    public struct ServiceRegime: Sendable, Hashable {
        public var weekday: ServiceDay
        public var saturday: ServiceDay
        public var sunday: ServiceDay

        init(_ regime: Components.Schemas.DashboardServiceRegime) {
            weekday = ServiceDay(regime.weekday)
            saturday = ServiceDay(regime.saturday)
            sunday = ServiceDay(regime.sunday)
        }
    }

    public struct ServiceDay: Sendable, Hashable {
        public var isCancelled: Bool
        public var tripsPerHour: [Double]?
        public var totalTrips: Int

        init(_ day: Components.Schemas.DashboardServiceDay) {
            isCancelled = day.cancelled
            tripsPerHour = day.tripsPerHour
            totalTrips = day.totalTrips
        }
    }
}
