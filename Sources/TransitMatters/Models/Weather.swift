import TransitMattersAPI

/// One hour's weather in downtown Boston, from Open-Meteo.
public struct HourlyWeather: Sendable, Hashable {
    /// The hour in Boston local time, without an offset (`2026-04-22T14:00`).
    public var timestamp: String
    public var temperatureFahrenheit: Double?
    /// WMO weather code.
    public var weatherCode: Int?
    /// A coarse label such as `clear`, `cloudy`, `rain` or `snow`.
    public var condition: String?
    /// Precipitation over the hour, in inches.
    public var precipitationInches: Double?
    /// Relative humidity, from 0 to 100.
    public var humidityPercent: Int?
    public var windSpeedMph: Double?

    init(_ entry: Components.Schemas.WeatherHourlyEntry) {
        timestamp = entry.timestamp
        temperatureFahrenheit = entry.temperature_f
        weatherCode = entry.weather_code
        condition = entry.condition
        precipitationInches = entry.precipitation_in
        humidityPercent = entry.humidity_pct
        windSpeedMph = entry.wind_mph
    }
}
