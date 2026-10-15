import TransitMattersAPI

/// Alert-based delay totals for a line over one aggregation period, by cause.
public struct LineDelays: Sendable, Hashable {
    public var date: String
    public var line: String
    public var totalDelayTime: Int
    public var brakeProblem: Int
    public var carTraffic: Int
    public var disabledVehicle: Int
    public var doorProblem: Int
    public var fire: Int
    public var flooding: Int
    public var mechanicalProblem: Int
    public var medicalEmergency: Int
    public var other: Int
    public var policeActivity: Int
    public var powerProblem: Int
    public var signalProblem: Int
    public var switchProblem: Int
    public var trackIssue: Int
    public var trackWork: Int

    init(_ entry: Components.Schemas.LineDelayEntry) {
        date = entry.date
        line = entry.line
        totalDelayTime = entry.total_delay_time
        brakeProblem = entry.brake_problem
        carTraffic = entry.car_traffic
        disabledVehicle = entry.disabled_vehicle
        doorProblem = entry.door_problem
        fire = entry.fire
        flooding = entry.flooding
        mechanicalProblem = entry.mechanical_problem
        medicalEmergency = entry.medical_emergency
        other = entry.other
        policeActivity = entry.police_activity
        powerProblem = entry.power_problem
        signalProblem = entry.signal_problem
        switchProblem = entry.switch_problem
        trackIssue = entry.track_issue
        trackWork = entry.track_work
    }
}

/// Trip counts, time and distance for a line over one aggregation period.
public struct TripMetrics: Sendable, Hashable {
    public var date: String
    public var line: String
    public var count: Double
    public var totalTime: Double
    public var milesCovered: Double
    public var averageCarAge: Double?
    public var percentNewTrips: Double?

    init(_ entry: Components.Schemas.TripMetricsEntry) {
        date = entry.date
        line = entry.line
        count = entry.count
        totalTime = entry.total_time
        milesCovered = entry.miles_covered
        averageCarAge = entry.avg_car_age
        percentNewTrips = entry.pct_new_trips
    }
}

/// Scheduled service for a route over a date range.
public struct ScheduledService: Sendable, Hashable {
    /// Service levels for one representative day.
    public struct DayServiceLevels: Sendable, Hashable {
        public var date: String
        public var serviceLevels: [Int]

        init(_ levels: Components.Schemas.ByDayKindServiceLevels) {
            date = levels.date
            serviceLevels = levels.service_levels
        }
    }

    /// Service levels for each kind of day.
    public struct ServiceLevels: Sendable, Hashable {
        public var weekday: DayServiceLevels?
        public var saturday: DayServiceLevels?
        public var sunday: DayServiceLevels?

        init(_ levels: Components.Schemas.ServiceLevelsByDayKind) {
            weekday = levels.weekday.map(DayServiceLevels.init)
            saturday = levels.saturday.map(DayServiceLevels.init)
            sunday = levels.sunday.map(DayServiceLevels.init)
        }
    }

    public struct Count: Sendable, Hashable {
        public var date: String
        public var count: Double
    }

    public var startDate: String
    public var endDate: String
    public var startDateServiceLevels: ServiceLevels
    public var endDateServiceLevels: ServiceLevels
    public var counts: [Count]

    init(_ response: Components.Schemas.GetScheduledServiceResponse) {
        startDate = response.start_date
        endDate = response.end_date
        startDateServiceLevels = ServiceLevels(response.start_date_service_levels)
        endDateServiceLevels = ServiceLevels(response.end_date_service_levels)
        counts = response.counts.map { Count(date: $0.date, count: $0.count) }
    }
}

/// Ridership for a line on one date.
public struct RidershipCount: Sendable, Hashable {
    public var date: String
    public var count: Int

    init(_ entry: Components.Schemas.RidershipEntry) {
        date = entry.date
        count = entry.count
    }
}

/// Scheduled and delivered service hours for a line over one aggregation period.
public struct ServiceHours: Sendable, Hashable {
    public var date: String
    public var scheduled: Double
    public var delivered: Double

    init(_ entry: Components.Schemas.ServiceHoursEntry) {
        date = entry.date
        scheduled = entry.scheduled
        delivered = entry.delivered
    }
}

/// Speed restrictions on a line on one date.
public struct SpeedRestrictions: Sendable, Hashable {
    public struct Zone: Sendable, Hashable, Identifiable {
        public var id: String
        public var date: String
        public var lineID: String
        public var description: String
        public var direction: String
        public var reason: String
        public var fromStopID: String?
        public var toStopID: String?
        public var reported: String
        public var speedMph: Int
        public var trackFeet: Int

        init(_ zone: Components.Schemas.SpeedRestrictionZone) {
            id = zone.id
            date = zone.date
            lineID = zone.lineId
            description = zone.description
            direction = zone.direction
            reason = zone.reason
            fromStopID = zone.fromStopId
            toStopID = zone.toStopId
            reported = zone.reported
            speedMph = zone.speedMph
            trackFeet = zone.trackFeet
        }
    }

    /// Whether the API has speed restriction data for the requested date.
    public var isAvailable: Bool
    /// The date the data is from.
    public var date: String?
    public var zones: [Zone]

    init(_ response: Components.Schemas.SpeedRestrictionsResponse) {
        isAvailable = response.available
        date = response.date
        zones = (response.zones ?? []).map(Zone.init)
    }
}

/// Prediction accuracy for a route over one week.
public struct TimePredictionWeek: Sendable, Hashable {
    public struct Bucket: Sendable, Hashable {
        public var week: String
        public var mode: String
        public var routeID: String
        public var bin: String
        public var arrivalDeparture: String
        public var predictionCount: Int
        public var accuratePredictionCount: Int

        init(_ bucket: Components.Schemas.TimePredictionBucket) {
            week = bucket.weekly
            mode = bucket.mode
            routeID = bucket.route_id
            bin = bucket.bin
            arrivalDeparture = bucket.arrival_departure
            predictionCount = bucket.num_predictions
            accuratePredictionCount = bucket.num_accurate_predictions
        }
    }

    public var routeID: String
    public var week: String
    public var buckets: [Bucket]

    init(_ week: Components.Schemas.TimePredictionWeek) {
        routeID = week.routeId
        self.week = week.week
        buckets = week.prediction.map(Bucket.init)
    }
}
