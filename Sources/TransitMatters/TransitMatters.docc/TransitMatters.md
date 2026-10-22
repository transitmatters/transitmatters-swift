# ``TransitMatters``

A Swift client for the TransitMatters Data Dashboard API.

@Metadata {
    @PageImage(purpose: icon, source: "flask", alt: "The TransitMatters Labs flask")
}

## Overview

TransitMatters is a client for the API behind the [TransitMatters Data Dashboard](https://dashboard.transitmatters.org). Use it to get MBTA headways, travel times, dwells, ridership, speed restrictions, service levels and alerts.

```swift
import TransitMatters

let client = TransitMattersClient()
let headways = try await client.headways(
    on: ServiceDate(year: 2024, month: 5, day: 1),
    stops: ["70061"]
)
```

Every request is a method on ``TransitMattersClient``. Methods take dates as ``ServiceDate`` values, return plain model types, and throw ``TransitMattersError``.

## Topics

### Essentials

- <doc:GettingStarted>
- ``TransitMattersClient``
- ``ServiceDate``
- ``TransitMattersError``

### Single-day events

- ``HeadwayEvent``
- ``DwellEvent``
- ``TravelTimeEvent``
- ``HistoricalAlert``
- ``SpeedRestrictions``

### Statistics over date ranges

- ``AggregateStatistics``
- ``DailyAggregate``
- ``HeadwayDailyAggregate``
- ``TimeOfDayAggregate``
- ``TravelTimeBreakdown``

### Line metrics

- ``Aggregation``
- ``DelayAggregation``
- ``LineDelays``
- ``TripMetrics``
- ``ScheduledService``
- ``RidershipCount``
- ``ServiceHours``

### Current data and reference

- ``LiveAlert``
- ``TimePredictionWeek``
- ``Facility``
- ``ServiceRidershipDashboard``
- ``Routes``
- ``RouteStops``
- ``HealthStatus``
