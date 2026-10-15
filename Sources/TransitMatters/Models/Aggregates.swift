import TransitMattersAPI

/// Summary statistics over a set of events, in seconds.
public struct AggregateStatistics: Sendable, Hashable {
    public var count: Int
    public var mean: Double
    public var min: Double
    public var max: Double
    public var standardDeviation: Double
    public var sum: Double
    public var percentile25: Double
    public var median: Double
    public var percentile75: Double
}

/// Statistics for one service date.
public struct DailyAggregate: Sendable, Hashable {
    /// Service date (`YYYY-MM-DD`).
    public var serviceDate: String
    /// `all` for the whole day. ``TransitMattersClient/travelTimeBreakdown(from:to:dates:)`` also
    /// returns `am_peak`, `pm_peak` and `off_peak` rows.
    public var peak: String
    public var isHoliday: Bool
    public var isWeekend: Bool
    public var statistics: AggregateStatistics

    init(_ row: Components.Schemas.AggregateByDate) {
        serviceDate = row.service_date
        peak = row.peak
        isHoliday = row.holiday
        isWeekend = row.weekend
        statistics = AggregateStatistics(
            count: row.count, mean: row.mean, min: row.min, max: row.max, standardDeviation: row.std,
            sum: row.sum, percentile25: row._25_percnt_, median: row._50_percnt_, percentile75: row._75_percnt_
        )
    }
}

/// Headway statistics for one service date, with bunching and on-time counts.
public struct HeadwayDailyAggregate: Sendable, Hashable {
    /// Service date (`YYYY-MM-DD`).
    public var serviceDate: String
    public var peak: String
    public var isHoliday: Bool
    public var isWeekend: Bool
    public var bunchedCount: Int
    public var onTimeCount: Int
    public var statistics: AggregateStatistics

    init(_ row: Components.Schemas.HeadwayAggregateByDate) {
        serviceDate = row.service_date
        peak = row.peak
        isHoliday = row.holiday
        isWeekend = row.weekend
        bunchedCount = row.bunched
        onTimeCount = row.on_time
        statistics = AggregateStatistics(
            count: row.count, mean: row.mean, min: row.min, max: row.max, standardDeviation: row.std,
            sum: row.sum, percentile25: row._25_percnt_, median: row._50_percnt_, percentile75: row._75_percnt_
        )
    }
}

/// Statistics for one 30-minute departure-time bucket.
public struct TimeOfDayAggregate: Sendable, Hashable {
    /// Bucket start as `1970-01-01THH:MM:SS`. Departures after midnight and before 03:30 use `1970-01-02`.
    public var bucketStart: String
    public var isPeakDay: Bool
    public var statistics: AggregateStatistics

    init(_ row: Components.Schemas.AggregateByTime) {
        bucketStart = row.dep_time_from_epoch
        isPeakDay = row.is_peak_day
        statistics = AggregateStatistics(
            count: row.count, mean: row.mean, min: row.min, max: row.max, standardDeviation: row.std,
            sum: row.sum, percentile25: row._25_percnt_, median: row._50_percnt_, percentile75: row._75_percnt_
        )
    }
}

/// Travel time statistics by date and by time of day.
public struct TravelTimeBreakdown: Sendable, Hashable {
    /// An `all` row for each date, then a row per peak period.
    public var byDate: [DailyAggregate]
    /// One row per 30-minute departure bucket, separately for peak and non-peak days.
    public var byTimeOfDay: [TimeOfDayAggregate]

    init(_ response: Components.Schemas.TravelTimeAggregate2Response) {
        byDate = response.by_date.map(DailyAggregate.init)
        byTimeOfDay = response.by_time.map(TimeOfDayAggregate.init)
    }
}
