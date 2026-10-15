import TransitMattersAPI

/// Every route ID the dashboard supports, by mode.
public struct Routes: Sendable, Hashable {
    public var rapidTransit: [String]
    public var bus: [String]
    public var commuterRail: [String]
    public var ferry: [String]

    init(_ response: Components.Schemas.RoutesResponse) {
        rapidTransit = response.rapid_transit
        bus = response.bus
        commuterRail = response.commuter_rail
        ferry = response.ferry
    }
}

/// The stations and stops on one route.
public struct RouteStops: Sendable, Hashable {
    public struct Station: Sendable, Hashable {
        public var name: String
        public var stationID: String
        public var order: Double
        public var branches: [String]?
        /// Stop IDs at this station, keyed by direction (`"0"` or `"1"`).
        public var stopIDsByDirection: [String: [String]]
        public var isAccessible: Bool?
        public var hasPedalAndPark: Bool?
        public var hasEnclosedBikeParking: Bool?
        public var isTerminus: Bool?
        public var isDisabled: Bool?
        public var shortName: String?

        init(_ stop: Components.Schemas.StationStop) {
            name = stop.stop_name
            stationID = stop.station
            order = stop.order
            branches = stop.branches
            stopIDsByDirection = stop.stops.additionalProperties
            isAccessible = stop.accessible
            hasPedalAndPark = stop.pedal_park
            hasEnclosedBikeParking = stop.enclosed_bike_parking
            isTerminus = stop.terminus
            isDisabled = stop.disabled
            shortName = stop.short
        }
    }

    public var type: String
    /// Direction names keyed by direction (`"0"` or `"1"`).
    public var directions: [String: String]
    public var stations: [Station]
    public var serviceStart: String?
    public var serviceEnd: String?

    init(_ response: Components.Schemas.StopsResponse) {
        type = response._type
        directions = response.direction.additionalProperties
        stations = response.stations.map(Station.init)
        serviceStart = response.service_start
        serviceEnd = response.service_end
    }
}

/// An elevator, escalator or other station facility from the MBTA v3 API.
public struct Facility: Sendable, Hashable, Identifiable {
    public struct Property: Sendable, Hashable {
        public var name: String
        public var value: String?
    }

    public var id: String
    /// The kind of facility, for example `ELEVATOR` or `ESCALATOR`.
    public var type: String
    public var longName: String?
    public var shortName: String?
    public var latitude: Double?
    public var longitude: Double?
    /// Properties in API order. A name can appear more than once.
    public var properties: [Property]
    /// The stop the facility belongs to.
    public var stopID: String?

    init(_ facility: Components.Schemas.Facility) {
        let attributes = facility.attributes
        id = facility.id
        type = attributes._type
        longName = attributes.long_name
        shortName = attributes.short_name
        latitude = attributes.latitude.flatMap(Double.init)
        longitude = attributes.longitude.flatMap(Double.init)
        properties = (attributes.properties ?? []).map { Property(name: $0.name, value: $0.value) }
        stopID = facility.relationships?.stop?.data?.id
    }
}

/// The result of the API's health checks.
public struct HealthStatus: Sendable, Hashable {
    /// `pass` or `fail`.
    public var status: String
    /// Failure details keyed by check name. Empty when every check passed.
    public var failedChecks: [String: String]

    public var isHealthy: Bool { status == "pass" }

    init(_ response: Components.Schemas.HealthcheckResponse) {
        status = response.status
        failedChecks = response.failed_checks?.additionalProperties ?? [:]
    }
}
