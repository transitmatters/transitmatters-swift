import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import TransitMattersAPI

/// A client for the TransitMatters Data Dashboard API.
///
/// Stop IDs, route IDs and line IDs are plain strings, in the format each method documents.
/// ``routes()`` lists valid route IDs, and ``stops(route:)`` lists the stop IDs on a route.
public struct TransitMattersClient: Sendable {
    public enum Environment: Sendable, Hashable {
        case production
        case local
        case custom(URL)

        var url: URL {
            switch self {
            case .production: URL(string: "https://dashboard-api.labs.transitmatters.org")!
            case .local: URL(string: "http://localhost:5000")!
            case .custom(let url): url
            }
        }
    }

    private let api: any APIProtocol

    public init(environment: Environment = .production, session: URLSession = .shared) {
        self.init(serverURL: environment.url, transport: URLSessionTransport(configuration: .init(session: session)))
    }

    package init(serverURL: URL, transport: any ClientTransport) {
        self.api = Client(serverURL: serverURL, transport: transport)
    }

    // MARK: - Single day

    /// Headways for one service day, in departure order.
    ///
    /// - Parameter stops: Stop IDs. Rapid transit: 5-digit numeric (`70061`). Bus: `{route}-{direction}-{n}`
    ///   (`1-0-110`). Commuter rail: `{route}_{direction}_{stop_code}` (`CR-Fairmount_0_DB-2205-01`).
    public func headways(on date: ServiceDate, stops: [String]) async throws -> [HeadwayEvent] {
        let output = try await send {
            try await api.getHeadways(path: .init(user_date: date.description), query: .init(stop: stops))
        }
        switch output {
        case .ok(let response): return try response.body.json.map(HeadwayEvent.init)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Dwells for one service day, in time order.
    ///
    /// - Parameter stops: Stop IDs, in the format ``headways(on:stops:)`` describes.
    public func dwells(on date: ServiceDate, stops: [String]) async throws -> [DwellEvent] {
        let output = try await send {
            try await api.getDwells(path: .init(user_date: date.description), query: .init(stop: stops))
        }
        switch output {
        case .ok(let response): return try response.body.json.map(DwellEvent.init)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Travel times between stops for one service day, in departure order.
    ///
    /// - Parameters:
    ///   - origins: Origin stop IDs, in the format ``headways(on:stops:)`` describes.
    ///   - destinations: Destination stop IDs.
    public func travelTimes(on date: ServiceDate, from origins: [String], to destinations: [String]) async throws -> [TravelTimeEvent] {
        let output = try await send {
            try await api.getTravelTimes(
                path: .init(user_date: date.description),
                query: .init(from_stop: origins, to_stop: destinations)
            )
        }
        switch output {
        case .ok(let response): return try response.body.json.map(TravelTimeEvent.init)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Archived alerts that were in effect on a past day.
    ///
    /// - Parameter routes: Route IDs, as ``routes()`` lists them (`Red`, `66`, `CR-Fairmount`, `Boat-F1`).
    /// - Returns: `nil` when there's no archive for that day: dates before 2017-11-06, or when the
    ///   day's archive can't be read.
    public func alerts(on date: ServiceDate, routes: [String]) async throws -> [HistoricalAlert]? {
        let output: Operations.getHistoricalAlerts.Output
        do {
            output = try await api.getHistoricalAlerts(
                path: .init(user_date: date.description),
                query: .init(route: routes)
            )
        } catch let error as ClientError where error.response?.status == .ok && error.isNullBody {
            // The spec marks this body nullable, but the generator models it as a non-optional array.
            return nil
        } catch let error as ClientError {
            throw TransitMattersError.requestFailed(underlying: error.underlyingError)
        }
        switch output {
        case .ok(let response): return try response.body.json.map(HistoricalAlert.init)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Speed restrictions on a rapid transit line on one date.
    ///
    /// - Parameter line: `line-Red`, `line-Orange`, `line-Blue` or `line-Green`. Case-sensitive.
    public func speedRestrictions(line: String, on date: ServiceDate) async throws -> SpeedRestrictions {
        let output = try await send {
            try await api.getSpeedRestrictions(query: .init(line_id: line, date: date.description))
        }
        switch output {
        case .ok(let response): return SpeedRestrictions(try response.body.json)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    // MARK: - Date ranges

    /// Travel time statistics per service date. Every row's `peak` is `all`.
    ///
    /// - Parameters:
    ///   - origins: Origin stop IDs, in the format ``headways(on:stops:)`` describes.
    ///   - destinations: Destination stop IDs.
    ///   - dates: The service dates to include.
    public func aggregateTravelTimes(from origins: [String], to destinations: [String], dates: ClosedRange<ServiceDate>) async throws -> [DailyAggregate] {
        let output = try await send {
            try await api.getAggregateTravelTimes(query: .init(
                start_date: dates.lowerBound.description,
                end_date: dates.upperBound.description,
                from_stop: origins,
                to_stop: destinations
            ))
        }
        switch output {
        case .ok(let response): return try response.body.json.map(DailyAggregate.init)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Travel time statistics by date (including peak-period rows) and by time of day.
    ///
    /// - Parameters:
    ///   - origins: Origin stop IDs, in the format ``headways(on:stops:)`` describes.
    ///   - destinations: Destination stop IDs.
    ///   - dates: The service dates to include.
    public func travelTimeBreakdown(from origins: [String], to destinations: [String], dates: ClosedRange<ServiceDate>) async throws -> TravelTimeBreakdown {
        let output = try await send {
            try await api.getAggregateTravelTimesV2(query: .init(
                start_date: dates.lowerBound.description,
                end_date: dates.upperBound.description,
                from_stop: origins,
                to_stop: destinations
            ))
        }
        switch output {
        case .ok(let response): return TravelTimeBreakdown(try response.body.json)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Headway statistics per service date.
    ///
    /// - Parameter stops: Stop IDs, in the format ``headways(on:stops:)`` describes.
    public func aggregateHeadways(stops: [String], dates: ClosedRange<ServiceDate>) async throws -> [HeadwayDailyAggregate] {
        let output = try await send {
            try await api.getAggregateHeadways(query: .init(
                start_date: dates.lowerBound.description,
                end_date: dates.upperBound.description,
                stop: stops
            ))
        }
        switch output {
        case .ok(let response): return try response.body.json.map(HeadwayDailyAggregate.init)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Dwell statistics per service date.
    ///
    /// - Parameter stops: Stop IDs, in the format ``headways(on:stops:)`` describes.
    public func aggregateDwells(stops: [String], dates: ClosedRange<ServiceDate>) async throws -> [DailyAggregate] {
        let output = try await send {
            try await api.getAggregateDwells(query: .init(
                start_date: dates.lowerBound.description,
                end_date: dates.upperBound.description,
                stop: stops
            ))
        }
        switch output {
        case .ok(let response): return try response.body.json.map(DailyAggregate.init)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Alert-based delays on a line, by cause.
    ///
    /// - Parameter line: Rapid transit: `Red`, `Orange`, `Blue`, `Green-B` through `Green-E`, `Mattapan`.
    ///   Commuter rail: `CR-Fairmount`, `CR-Lowell`, etc.
    public func lineDelays(line: String, dates: ClosedRange<ServiceDate>, aggregation: DelayAggregation = .weekly) async throws -> [LineDelays] {
        let output = try await send {
            try await api.getLineDelays(query: .init(
                start_date: dates.lowerBound.description,
                end_date: dates.upperBound.description,
                line: line,
                agg: .init(rawValue: aggregation.rawValue)
            ))
        }
        switch output {
        case .ok(let response): return try response.body.json.map(LineDelays.init)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Trip counts, time and distance on a rapid transit line.
    ///
    /// - Parameter line: `line-red`, `line-orange`, `line-blue`, `line-green` or `line-mattapan`.
    /// - Throws: ``TransitMattersError/dateRangeTooLarge(message:)`` when the range has too many
    ///   entries for `aggregation`.
    public func tripMetrics(line: String, dates: ClosedRange<ServiceDate>, aggregation: Aggregation) async throws -> [TripMetrics] {
        let output = try await send {
            try await api.getTripMetrics(query: .init(
                start_date: dates.lowerBound.description,
                end_date: dates.upperBound.description,
                agg: .init(rawValue: aggregation.rawValue)!,
                line: line
            ))
        }
        switch output {
        case .ok(let response): return try response.body.json.map(TripMetrics.init)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .forbidden(let response): throw TransitMattersError.dateRangeTooLarge(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Scheduled service on a route.
    ///
    /// - Parameter route: A route ID, as ``routes()`` lists them.
    public func scheduledService(route: String, dates: ClosedRange<ServiceDate>, aggregation: Aggregation) async throws -> ScheduledService {
        let output = try await send {
            try await api.getScheduledService(query: .init(
                start_date: dates.lowerBound.description,
                end_date: dates.upperBound.description,
                route_id: route,
                agg: .init(rawValue: aggregation.rawValue)!
            ))
        }
        switch output {
        case .ok(let response): return ScheduledService(try response.body.json)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Ridership on a line.
    ///
    /// - Parameter line: Rapid transit: `line-Red`, `line-Orange`, `line-Blue`, `line-Green`.
    ///   Bus: `line-{route}` (`line-66`). Commuter rail: `line-{line}` (`line-Fairmount`). Ferry: `line-F1`, etc.
    public func ridership(line: String, dates: ClosedRange<ServiceDate>) async throws -> [RidershipCount] {
        let output = try await send {
            try await api.getRidership(query: .init(
                start_date: dates.lowerBound.description,
                end_date: dates.upperBound.description,
                line_id: line
            ))
        }
        switch output {
        case .ok(let response): return try response.body.json.map(RidershipCount.init)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Scheduled and delivered service hours on a rapid transit line.
    ///
    /// - Parameter line: `line-red`, `line-orange`, `line-blue`, `line-green` or `line-mattapan`.
    public func serviceHours(line: String, dates: ClosedRange<ServiceDate>, aggregation: Aggregation) async throws -> [ServiceHours] {
        let output = try await send {
            try await api.getServiceHours(query: .init(
                line_id: line,
                start_date: dates.lowerBound.description,
                end_date: dates.upperBound.description,
                agg: .init(rawValue: aggregation.rawValue)!
            ))
        }
        switch output {
        case .ok(let response): return try response.body.json.map(ServiceHours.init)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    // MARK: - Current data and reference

    /// Current alerts from the MBTA v3 API.
    public func currentAlerts() async throws -> [LiveAlert] {
        switch try await send({ try await api.getCurrentAlerts() }) {
        case .ok(let response): return try response.body.json.map(LiveAlert.init)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Prediction accuracy for a route, by week.
    ///
    /// - Parameter route: A route ID, as ``routes()`` lists them.
    public func timePredictions(route: String) async throws -> [TimePredictionWeek] {
        switch try await send({ try await api.getTimePredictions(query: .init(route_id: route)) }) {
        case .ok(let response): return try response.body.json.map(TimePredictionWeek.init)
        case .badRequest(let response): throw TransitMattersError.badRequest(message: try response.body.json.Message)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Elevators, escalators and other station facilities.
    public func facilities() async throws -> [Facility] {
        switch try await send({ try await api.getFacilities() }) {
        case .ok(let response): return try response.body.json.data.map(Facility.init)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Combined service and ridership data for the overview dashboard.
    public func serviceRidershipDashboard() async throws -> ServiceRidershipDashboard {
        switch try await send({ try await api.getServiceRidershipDashboard() }) {
        case .ok(let response): return ServiceRidershipDashboard(try response.body.json)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Every route ID the dashboard supports, by mode.
    public func routes() async throws -> Routes {
        switch try await send({ try await api.getRoutes() }) {
        case .ok(let response): return Routes(try response.body.json)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// The stations and stop IDs on a route.
    ///
    /// - Parameter route: Rapid transit: `Red`, `Orange`, `Blue`, `Green`, `Mattapan`. Bus: `1`, `66`, etc.
    ///   Commuter rail: `CR-Fairmount`, etc. Ferry: `Boat-F1`, etc.
    public func stops(route: String) async throws -> RouteStops {
        switch try await send({ try await api.getStopsForRoute(path: .init(route_id: route)) }) {
        case .ok(let response): return RouteStops(try response.body.json)
        case .notFound(let response): throw TransitMattersError.routeNotFound(message: try response.body.json.error)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    /// Runs the API's health checks. A failing check is reported in the result, not thrown.
    public func healthcheck() async throws -> HealthStatus {
        switch try await send({ try await api.getHealthcheck() }) {
        case .ok(let response): return HealthStatus(try response.body.json)
        case .internalServerError(let response): return HealthStatus(try response.body.json)
        case .undocumented(let status, _): throw TransitMattersError.unexpectedStatus(status)
        }
    }

    // MARK: - Helpers

    /// Runs a generated operation, replacing the runtime's `ClientError` with ``TransitMattersError``.
    private func send<Output>(_ operation: () async throws -> Output) async throws -> Output {
        do {
            return try await operation()
        } catch let error as ClientError {
            throw TransitMattersError.requestFailed(underlying: error.underlyingError)
        }
    }
}

extension ClientError {
    /// Whether decoding failed because the response body was JSON `null`.
    fileprivate var isNullBody: Bool {
        guard case DecodingError.valueNotFound(_, let context) = underlyingError else { return false }
        return context.codingPath.isEmpty
    }
}
