# TransitMatters Swift

[![CI](https://github.com/transitmatters/transitmatters-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/transitmatters/transitmatters-swift/actions/workflows/ci.yml)

A Swift client for the [TransitMatters Data Dashboard](https://dashboard.transitmatters.org) API: MBTA headways, travel times, dwells, ridership, speed restrictions, service levels and alerts.

```swift
import TransitMatters

let client = TransitMattersClient()
let headways = try await client.headways(
    on: ServiceDate(year: 2024, month: 5, day: 1),
    stops: ["70061"]
)
```

## Requirements

- Swift 6.4 (Xcode 27)
- iOS 16, macOS 13, tvOS 16, watchOS 9, visionOS 1, or Linux

## Installation

In Xcode, choose **File → Add Package Dependencies…** and enter:

```
https://github.com/transitmatters/transitmatters-swift
```

Or add it to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/transitmatters/transitmatters-swift", .upToNextMinor(from: "0.1.0")),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "TransitMatters", package: "transitmatters-swift"),
    ]),
]
```

While the package is below 1.0, minor versions may contain breaking changes, so pin with `.upToNextMinor`.

> [!NOTE]
> The client is generated at build time by Apple's [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator) plugin. Xcode asks you to **Trust & Enable** it the first time you build. On CI, pass `-skipPackagePluginValidation` to `xcodebuild`.

## Usage

### Finding stop IDs

Most endpoints take stop IDs. Look them up by route; each station lists its stop IDs by direction (`"0"` or `"1"`):

```swift
let routes = try await client.routes()   // routes.rapidTransit, .bus, .commuterRail, .ferry
let red = try await client.stops(route: "Red")

for station in red.stations {
    print(station.name, station.stopIDsByDirection)
}
```

Stop ID formats differ by mode:

| Mode | Format | Example |
|---|---|---|
| Rapid transit | 5-digit number | `70061` |
| Bus | `{route}-{direction}-{n}` | `1-0-110` |
| Commuter rail | `{route}_{direction}_{stop_code}` | `CR-Fairmount_0_DB-2205-01` |

### Dates

Dates are `ServiceDate` values: a calendar day, not a `Date`, so a request can't drift to the neighboring day because of the device's time zone. Date-range methods take a `ClosedRange<ServiceDate>`.

```swift
let start = ServiceDate(year: 2024, month: 5, day: 1)
let end = ServiceDate(year: 2024, month: 5, day: 31)
let today = ServiceDate(Date())          // the current day in the user's calendar
let parsed = ServiceDate("2024-05-01")   // optional; nil if malformed

// Alewife to Downtown Crossing, southbound
let daily = try await client.aggregateTravelTimes(from: ["70061"], to: ["70077"], dates: start...end)
for day in daily {
    print(day.serviceDate, day.statistics.median)
}
```

### Errors

Every method throws `TransitMattersError`:

```swift
do {
    let metrics = try await client.tripMetrics(line: "line-red", dates: start...end, aggregation: .daily)
} catch TransitMattersError.badRequest(let message) {
    // Unknown stop or route, malformed parameter, etc.
} catch TransitMattersError.dateRangeTooLarge(let message) {
    // Too many days for this aggregation; try .weekly or .monthly.
} catch {
    // .routeNotFound, .unexpectedStatus, or .requestFailed (network and decoding errors)
}
```

### Environments

The client talks to the production API by default. Point it elsewhere for development:

```swift
let local = TransitMattersClient(environment: .local)   // http://localhost:5000
let custom = TransitMattersClient(environment: .custom(URL(string: "https://example.com")!))
```

You can also pass your own `URLSession`, for example to configure caching or timeouts.

## API overview

| Method | Returns |
|---|---|
| **Single day** | |
| `headways(on:stops:)` | Time between departures |
| `dwells(on:stops:)` | Time spent at stops |
| `travelTimes(on:from:to:)` | Trip times between stops |
| `alerts(on:routes:)` | Archived alerts (`nil` before 2017-11-06) |
| `speedRestrictions(line:on:)` | Slow zones in effect |
| **Date ranges** | |
| `aggregateTravelTimes(from:to:dates:)` | Daily travel time statistics |
| `travelTimeBreakdown(from:to:dates:)` | Travel times by date, peak period and time of day |
| `aggregateHeadways(stops:dates:)` | Daily headway statistics, with bunching and on-time counts |
| `aggregateDwells(stops:dates:)` | Daily dwell statistics |
| `lineDelays(line:dates:aggregation:)` | Alert-based delays by cause |
| `tripMetrics(line:dates:aggregation:)` | Trip counts, time and distance |
| `scheduledService(route:dates:aggregation:)` | Scheduled trips |
| `ridership(line:dates:)` | Ridership counts |
| `serviceHours(line:dates:aggregation:)` | Scheduled and delivered service hours |
| **Current and reference** | |
| `currentAlerts()` | Live alerts from the MBTA |
| `timePredictions(route:)` | Weekly prediction accuracy |
| `facilities()` | Elevators, escalators and other facilities |
| `serviceRidershipDashboard()` | Overview dashboard data |
| `routes()` / `stops(route:)` | Route and stop IDs |
| `healthcheck()` | API health checks |

Line ID formats vary by endpoint (`Red`, `line-Red`, `line-red`); each method's documentation lists the ones it accepts.

## Development

```sh
swift build
swift test
```

`swift test` needs full Xcode, not just the Command Line Tools. If it can't find XCTest, run `sudo xcode-select -s /Applications/Xcode.app`.

### Updating the API spec

The OpenAPI spec is vendored from [t-performance-dash](https://github.com/transitmatters/t-performance-dash) at a pinned commit, recorded in `Sources/TransitMattersAPI/openapi.lock`. To update it:

```sh
scripts/update-openapi.sh            # latest on main
scripts/update-openapi.sh <ref>      # a branch, tag, or commit SHA
```

A weekly workflow also does this and opens a pull request when the spec changes.

The generated client is `package`-scoped and not part of the public API. `TransitMattersClient` and its model types wrap it, so spec changes don't reach library users unless the wrapper changes.

## License

MIT. See [LICENSE](LICENSE).
