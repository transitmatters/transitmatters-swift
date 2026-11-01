import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
@testable import TransitMatters

/// Answers every request with a canned status and JSON body, and records the last request.
final class MockTransport: ClientTransport, @unchecked Sendable {
    let status: HTTPResponse.Status
    let body: String
    private(set) var lastRequest: HTTPRequest?

    init(status: HTTPResponse.Status = .ok, body: String) {
        self.status = status
        self.body = body
    }

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        lastRequest = request
        var fields = HTTPFields()
        fields[.contentType] = "application/json"
        return (HTTPResponse(status: status, headerFields: fields), HTTPBody(self.body))
    }
}

func makeClient(_ transport: MockTransport) -> TransitMattersClient {
    TransitMattersClient(serverURL: URL(string: "https://example.test")!, transport: transport)
}

let errorBody = #"{"Code": "BadRequestError", "Message": "bad stop"}"#

@Test func headwaysEncodesRequestAndMapsResponse() async throws {
    let transport = MockTransport(body: """
        [{"route_id": "Red", "direction": "0", "current_dep_dt": "2024-05-01 06:00:00",
          "headway_time_sec": 420.0, "benchmark_headway_time_sec": null, "vehicle_label": "1800"}]
        """)
    let events = try await makeClient(transport).headways(
        on: ServiceDate(year: 2024, month: 5, day: 1),
        stops: ["70061", "70063"]
    )

    #expect(transport.lastRequest?.path == "/api/headways/2024-05-01?stop=70061&stop=70063")
    #expect(events.count == 1)
    #expect(events[0].routeID == "Red")
    #expect(events[0].headwaySeconds == 420)
    #expect(events[0].benchmarkHeadwaySeconds == nil)
}

@Test func dateRangeAndAggregationAreEncoded() async throws {
    let transport = MockTransport(body: "[]")
    let start = ServiceDate(year: 2024, month: 1, day: 1)
    let end = ServiceDate(year: 2024, month: 3, day: 31)
    _ = try await makeClient(transport).tripMetrics(line: "line-red", dates: start...end, aggregation: .monthly)

    let path = try #require(transport.lastRequest?.path)
    #expect(path.hasPrefix("/api/tripmetrics?"))
    #expect(path.contains("start_date=2024-01-01"))
    #expect(path.contains("end_date=2024-03-31"))
    #expect(path.contains("agg=monthly"))
    #expect(path.contains("line=line-red"))
}

@Test func aggregatePercentilesAreMapped() async throws {
    let transport = MockTransport(body: """
        [{"count": 3, "mean": 2, "min": 1, "max": 3, "std": 1, "sum": 6, "25%": 1.5, "50%": 2, "75%": 2.5,
          "service_date": "2024-05-01", "peak": "all", "holiday": false, "weekend": false}]
        """)
    let day = ServiceDate(year: 2024, month: 5, day: 1)
    let rows = try await makeClient(transport).aggregateDwells(stops: ["70061"], dates: day...day)

    #expect(rows[0].statistics.percentile25 == 1.5)
    #expect(rows[0].statistics.median == 2)
    #expect(rows[0].statistics.percentile75 == 2.5)
    #expect(rows[0].serviceDate == "2024-05-01")
}

@Test func badRequestThrowsTypedError() async throws {
    let transport = MockTransport(status: .badRequest, body: errorBody)
    await #expect {
        try await makeClient(transport).dwells(on: ServiceDate(year: 2024, month: 5, day: 1), stops: ["nope"])
    } throws: { error in
        guard case TransitMattersError.badRequest(let message) = error else { return false }
        return message == "bad stop"
    }
}

@Test func tripMetricsForbiddenIsDateRangeTooLarge() async throws {
    let transport = MockTransport(status: .forbidden, body: errorBody)
    let day = ServiceDate(year: 2024, month: 5, day: 1)
    await #expect {
        try await makeClient(transport).tripMetrics(line: "line-red", dates: day...day, aggregation: .daily)
    } throws: { error in
        guard case TransitMattersError.dateRangeTooLarge = error else { return false }
        return true
    }
}

@Test func unknownRouteThrowsRouteNotFound() async throws {
    let transport = MockTransport(status: .notFound, body: #"{"error": "Route not found"}"#)
    await #expect {
        try await makeClient(transport).stops(route: "Purple")
    } throws: { error in
        guard case TransitMattersError.routeNotFound(let message) = error else { return false }
        return message == "Route not found"
    }
}

@Test func undocumentedStatusThrowsUnexpectedStatus() async throws {
    let transport = MockTransport(status: .serviceUnavailable, body: "{}")
    await #expect {
        try await makeClient(transport).routes()
    } throws: { error in
        guard case TransitMattersError.unexpectedStatus(503) = error else { return false }
        return true
    }
}

@Test func malformedBodyThrowsRequestFailed() async throws {
    let transport = MockTransport(body: #"{"rapid_transit": "not an array"}"#)
    await #expect {
        try await makeClient(transport).routes()
    } throws: { error in
        guard case TransitMattersError.requestFailed = error else { return false }
        return true
    }
}

@Test func historicalAlertsNullBodyIsNil() async throws {
    let transport = MockTransport(body: "null")
    let alerts = try await makeClient(transport).alerts(on: ServiceDate(year: 2016, month: 1, day: 1), routes: ["Red"])
    #expect(alerts == nil)
}

@Test func historicalAlertsArrayIsMapped() async throws {
    let transport = MockTransport(body: #"[{"valid_from": "2024-05-01T05:00:00", "valid_to": null, "text": "Shuttles"}]"#)
    let alerts = try await makeClient(transport).alerts(on: ServiceDate(year: 2024, month: 5, day: 1), routes: ["Red"])
    #expect(alerts?.first?.text == "Shuttles")
}

@Test func failingHealthcheckIsReturnedNotThrown() async throws {
    let transport = MockTransport(status: .internalServerError, body: """
        {"status": "fail", "failed_checks_sum": 1, "failed_checks": {"db": "timeout"}}
        """)
    let health = try await makeClient(transport).healthcheck()
    #expect(!health.isHealthy)
    #expect(health.failedChecks == ["db": "timeout"])
}

@Test func liveAlertNumericStopIDsBecomeStrings() async throws {
    let transport = MockTransport(body: """
        [{"id": "1", "type": "DELAY", "header": "Delays", "active_period": [], "stops": ["place-pktrm", 70061]}]
        """)
    let alerts = try await makeClient(transport).currentAlerts()
    #expect(alerts[0].stopIDs == ["place-pktrm", "70061"])
    #expect(alerts[0].routeIDs.isEmpty)
}

@Test func busTripMetricsEncodesFiltersAndMapsFleetFields() async throws {
    let transport = MockTransport(body: """
        [{"avg_bus_age": 9.7, "count": 215, "date": "2026-09-01", "fleet_mix_battery": 0, "fleet_mix_cng": 18.7,
          "fleet_mix_hybrid": 81.3, "fleet_trips": 214, "mean_speed_mph": 9.1, "median_speed_mph": 7.17,
          "miles_covered": 1000, "n_traversals": 4707, "pct_battery_trips": 0, "route": "1", "total_time": 360000}]
        """)
    let day = ServiceDate(year: 2026, month: 9, day: 1)
    let rows = try await makeClient(transport).busTripMetrics(
        route: "1", dates: day...day, timeBand: .amPeak, dayType: .businessDay
    )

    let path = try #require(transport.lastRequest?.path)
    #expect(path.hasPrefix("/api/bustripmetrics?"))
    #expect(path.contains("agg=daily"))
    #expect(path.contains("time_band=am_peak"))
    #expect(path.contains("day_type=business_day"))
    #expect(rows[0].fleetMix == ["battery": 0, "cng": 18.7, "hybrid": 81.3])
    #expect(rows[0].percentTripsByType == ["battery": 0])
    #expect(rows[0].fleetTrips == 214)
    #expect(rows[0].averageBusAge == 9.7)
    #expect(rows[0].medianSpeedMph == 7.17)
    #expect(rows[0].averageSpeedMph == 10)
}

@Test func slowestBusRoutesEncodesLimit() async throws {
    let transport = MockTransport(body: """
        [{"count": 117, "miles_covered": 223.179, "n_traversals": 1149, "route": "55", "total_time": 0}]
        """)
    let day = ServiceDate(year: 2026, month: 9, day: 1)
    let routes = try await makeClient(transport).slowestBusRoutes(dates: day...day, limit: 5)

    #expect(transport.lastRequest?.path?.contains("limit=5") == true)
    #expect(routes[0].route == "55")
    #expect(routes[0].averageSpeedMph == nil)
}

@Test func commuterRailTripMetricsMapsFleetMix() async throws {
    let transport = MockTransport(body: """
        [{"avg_cab_car_age": 10.6, "date": "2026-09-01", "fleet_mix_kawasaki": 7.3, "fleet_mix_mbb": 0,
          "fleet_mix_rotem": 92.7, "fleet_trips": 55, "route": "CR-Fairmount"}]
        """)
    let day = ServiceDate(year: 2026, month: 9, day: 1)
    let rows = try await makeClient(transport).commuterRailTripMetrics(route: "CR-Fairmount", dates: day...day)

    #expect(rows[0].fleetMix == ["kawasaki": 7.3, "mbb": 0, "rotem": 92.7])
    #expect(rows[0].averageCabCarAge == 10.6)
    #expect(rows[0].fleetTrips == 55)
}

@Test func commuterRailScorecardSummaryHasRouteIDs() async throws {
    let transport = MockTransport(body: """
        [{"routeId": "CR-Fairmount", "days": 4,
          "outbound": {"trips": 16.0, "firstTrip": 31620.0, "maxGapMidday": 90.0, "byHour": [0.0, null, 1.0]},
          "inbound": {"trips": 17.0}, "peakTrips": 8.0, "reversePeakTrips": 6.0}]
        """)
    let start = ServiceDate(year: 2026, month: 6, day: 1)
    let end = ServiceDate(year: 2026, month: 9, day: 30)
    let rows = try await makeClient(transport).commuterRailScorecard(
        route: "commuter-rail", dates: start...end, aggregation: .monthly, dayKind: .weekday
    )

    let path = try #require(transport.lastRequest?.path)
    #expect(path.contains("route_id=commuter-rail"))
    #expect(path.contains("day_kind=weekday"))
    #expect(rows[0].routeID == "CR-Fairmount")
    #expect(rows[0].date == nil)
    #expect(rows[0].outbound.firstTripSeconds == 31620)
    #expect(rows[0].outbound.longestMiddayGapMinutes == 90)
    #expect(rows[0].outbound.tripsByHour == [0, nil, 1])
    #expect(rows[0].inbound.lastTripSeconds == nil)
}

@Test func reliabilityMapsRideAndCommuterRailEntries() async throws {
    let transport = MockTransport(body: """
        [{"date": "2026-03-02", "days": 7, "cancelled": 5, "otpDenominator": 3305, "otpNumerator": 2931,
          "peak": {"cancelled": 2, "otpDenominator": 690, "otpNumerator": 558},
          "offPeak": {"cancelled": 3, "otpDenominator": 2615, "otpNumerator": 2373}},
         {"date": "2025-12-01", "days": 31, "completed": 90467, "onTime": 86078, "requests": 140556}]
        """)
    let start = ServiceDate(year: 2025, month: 12, day: 1)
    let end = ServiceDate(year: 2026, month: 3, day: 8)
    let rows = try await makeClient(transport).reliability(route: "RIDE", dates: start...end, aggregation: .weekly)

    #expect(rows[0].otpNumerator == 2931)
    #expect(rows[0].peak?.otpDenominator == 690)
    #expect(rows[0].offPeak?.cancelled == 3)
    #expect(rows[0].completed == nil)
    #expect(rows[1].onTime == 86078)
    #expect(rows[1].missed == nil)
    #expect(rows[1].peak == nil)
}

@Test func weatherIsMapped() async throws {
    let transport = MockTransport(body: """
        [{"timestamp": "2026-10-07T00:00", "temperature_f": 45.2, "weather_code": 0, "condition": "clear",
          "precipitation_in": 0.0, "humidity_pct": 58, "wind_mph": null}]
        """)
    let day = ServiceDate(year: 2026, month: 10, day: 7)
    let hours = try await makeClient(transport).weather(dates: day...day)

    #expect(transport.lastRequest?.path == "/api/weather?start_date=2026-10-07&end_date=2026-10-07")
    #expect(hours[0].temperatureFahrenheit == 45.2)
    #expect(hours[0].humidityPercent == 58)
    #expect(hours[0].windSpeedMph == nil)
}

@Test func timePredictionsDateRangeIsOptional() async throws {
    let transport = MockTransport(body: "[]")
    let client = makeClient(transport)

    _ = try await client.timePredictions(route: "Red")
    #expect(transport.lastRequest?.path == "/api/time_predictions?route_id=Red")

    let start = ServiceDate(year: 2026, month: 1, day: 1)
    let end = ServiceDate(year: 2026, month: 3, day: 31)
    _ = try await client.timePredictions(route: "Red", dates: start...end)
    #expect(transport.lastRequest?.path == "/api/time_predictions?route_id=Red&start_date=2026-01-01&end_date=2026-03-31")
}

@Test func combinedRouteSlashIsPercentEncoded() async throws {
    let transport = MockTransport(body: #"{"type": "bus", "direction": {}, "stations": []}"#)
    _ = try await makeClient(transport).stops(route: "SL4/SL5")
    #expect(transport.lastRequest?.path == "/api/stops/SL4%2FSL5")
}

@Test func serviceDateFormatting() {
    #expect(ServiceDate(year: 2024, month: 5, day: 1).description == "2024-05-01")
    #expect(ServiceDate("2024-05-01") == ServiceDate(year: 2024, month: 5, day: 1))
    #expect(ServiceDate("2024-5-1") == nil)
    #expect(ServiceDate("2024-13-01") == nil)
    #expect(ServiceDate(year: 2023, month: 12, day: 31) < ServiceDate(year: 2024, month: 1, day: 1))

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    // 2024-05-02 03:00 UTC is still May 1 in Boston.
    let date = Date(timeIntervalSince1970: 1_714_618_800)
    #expect(ServiceDate(date, calendar: calendar) == ServiceDate(year: 2024, month: 5, day: 1))
}
