# Getting Started

Add the package, find the stops you care about, and make your first request.

## Add the package

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

> Note: The client is generated at build time by Apple's [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator) plugin. Xcode asks you to **Trust & Enable** it the first time you build. On CI, pass `-skipPackagePluginValidation` to `xcodebuild`.

## Find stop IDs

Most methods take stop IDs. Look them up by route with ``TransitMattersClient/stops(route:)``; each station lists its stop IDs by direction (`"0"` or `"1"`):

```swift
let client = TransitMattersClient()
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

Line ID formats vary by method (`Red`, `line-Red`, `line-red`). Each method's documentation lists the ones it accepts.

## Pass dates

Dates are ``ServiceDate`` values: a calendar day, not a `Date`, so a request can't drift to the neighboring day because of the device's time zone. Methods that cover several days take a `ClosedRange<ServiceDate>`.

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

## Handle errors

Every method throws ``TransitMattersError``:

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

## Use another server

The client talks to the production API by default. Point it at a local copy of the [dashboard](https://github.com/transitmatters/t-performance-dash) or another server with ``TransitMattersClient/Environment``:

```swift
let local = TransitMattersClient(environment: .local)   // http://localhost:5000
let custom = TransitMattersClient(environment: .custom(URL(string: "https://example.com")!))
```

You can also pass your own `URLSession`, for example to configure caching or timeouts.
