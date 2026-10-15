import TransitMattersAPI

/// An archived alert that was in effect on a past day.
public struct HistoricalAlert: Sendable, Hashable {
    public var validFrom: String
    public var validTo: String?
    public var text: String?

    init(_ alert: Components.Schemas.Alert) {
        validFrom = alert.valid_from
        validTo = alert.valid_to
        text = alert.text
    }
}

/// A current alert from the MBTA v3 API.
public struct LiveAlert: Sendable, Hashable, Identifiable {
    public struct ActivePeriod: Sendable, Hashable {
        public var start: String?
        public var end: String?
        public var isCurrent: Bool
        public var isUpcoming: Bool
    }

    public var id: String
    public var type: String
    public var header: String
    public var description: String?
    public var activePeriods: [ActivePeriod]
    /// Affected stop IDs. The API sends some as numbers; they're all strings here.
    public var stopIDs: [String]
    public var routeIDs: [String]

    init(_ alert: Components.Schemas.LiveAlert) {
        id = alert.id
        type = alert._type
        header = alert.header
        description = alert.description
        activePeriods = alert.active_period.map {
            ActivePeriod(start: $0.start, end: $0.end, isCurrent: $0.current, isUpcoming: $0.upcoming)
        }
        stopIDs = alert.stops.compactMap { $0.value1 ?? $0.value2.map(String.init) }
        routeIDs = alert.routes ?? []
    }
}
