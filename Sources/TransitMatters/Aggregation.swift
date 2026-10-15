/// How results over a date range are grouped.
public enum Aggregation: String, Sendable, Hashable, CaseIterable {
    case daily
    case weekly
    case monthly
}

/// How line delay results are grouped. `/api/linedelays` doesn't support monthly aggregation.
public enum DelayAggregation: String, Sendable, Hashable, CaseIterable {
    case daily
    case weekly
}
