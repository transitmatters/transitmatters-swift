import TransitMattersAPI

/// The time between one departure and the previous one from the same stop.
public struct HeadwayEvent: Sendable, Hashable {
    public var routeID: String
    public var direction: String
    public var departure: String
    public var headwaySeconds: Double
    public var benchmarkHeadwaySeconds: Double?
    public var vehicleConsist: String?
    public var vehicleLabel: String

    init(_ event: Components.Schemas.HeadwayEvent) {
        routeID = event.route_id
        direction = event.direction
        departure = event.current_dep_dt
        headwaySeconds = event.headway_time_sec
        benchmarkHeadwaySeconds = event.benchmark_headway_time_sec
        vehicleConsist = event.vehicle_consist
        vehicleLabel = event.vehicle_label
    }
}

/// How long a vehicle stayed at a stop.
public struct DwellEvent: Sendable, Hashable {
    public var routeID: String
    public var direction: Int
    public var arrival: String
    public var departure: String
    public var dwellSeconds: Double
    public var vehicleConsist: String?
    public var vehicleLabel: String

    init(_ event: Components.Schemas.DwellEvent) {
        routeID = event.route_id
        direction = event.direction
        arrival = event.arr_dt
        departure = event.dep_dt
        dwellSeconds = event.dwell_time_sec
        vehicleConsist = event.vehicle_consist
        vehicleLabel = event.vehicle_label
    }
}

/// One trip between an origin and a destination stop.
public struct TravelTimeEvent: Sendable, Hashable {
    public var routeID: String
    public var direction: Int
    public var departure: String
    public var arrival: String
    public var travelTimeSeconds: Double
    public var benchmarkTravelTimeSeconds: Double?
    public var timetableBenchmarkTravelTimeSeconds: Double?
    public var vehicleConsist: String?
    public var vehicleLabel: String

    init(_ event: Components.Schemas.TravelTimeEvent) {
        routeID = event.route_id
        direction = event.direction
        departure = event.dep_dt
        arrival = event.arr_dt
        travelTimeSeconds = event.travel_time_sec
        benchmarkTravelTimeSeconds = event.benchmark_travel_time_sec
        timetableBenchmarkTravelTimeSeconds = event.tm_benchmark_travel_time_sec
        vehicleConsist = event.vehicle_consist
        vehicleLabel = event.vehicle_label
    }
}
