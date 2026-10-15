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
