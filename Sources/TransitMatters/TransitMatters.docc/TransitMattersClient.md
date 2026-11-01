# ``TransitMatters/TransitMattersClient``

## Topics

### Creating a client

- ``init(environment:session:)``
- ``Environment``

### Single day

- ``headways(on:stops:)``
- ``dwells(on:stops:)``
- ``travelTimes(on:from:to:)``
- ``alerts(on:routes:)``
- ``speedRestrictions(line:on:)``

### Date ranges

- ``aggregateTravelTimes(from:to:dates:)``
- ``travelTimeBreakdown(from:to:dates:)``
- ``aggregateHeadways(stops:dates:)``
- ``aggregateDwells(stops:dates:)``
- ``lineDelays(line:dates:aggregation:)``
- ``tripMetrics(line:dates:aggregation:)``
- ``scheduledService(route:dates:aggregation:)``
- ``ridership(line:dates:)``
- ``serviceHours(line:dates:aggregation:)``
- ``busTripMetrics(route:dates:aggregation:timeBand:dayType:)``
- ``slowestBusRoutes(dates:limit:)``
- ``commuterRailTripMetrics(route:dates:aggregation:)``
- ``commuterRailScorecard(route:dates:aggregation:dayKind:)``
- ``reliability(route:dates:aggregation:)``
- ``weather(dates:)``

### Current data and reference

- ``currentAlerts()``
- ``timePredictions(route:dates:)``
- ``facilities()``
- ``serviceRidershipDashboard()``
- ``routes()``
- ``stops(route:)``
- ``healthcheck()``
