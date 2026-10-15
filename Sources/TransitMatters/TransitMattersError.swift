/// An error from a ``TransitMattersClient`` request.
public enum TransitMattersError: Error, Sendable {
    /// The API rejected a parameter (HTTP 400), for example an unknown stop or a malformed date.
    case badRequest(message: String)
    /// The date range has too many entries for the requested aggregation (HTTP 403).
    case dateRangeTooLarge(message: String)
    /// No route has the requested ID (HTTP 404).
    case routeNotFound(message: String)
    /// The API answered with a status code the spec doesn't document.
    case unexpectedStatus(Int)
    /// The request couldn't be sent, or the response couldn't be read.
    case requestFailed(underlying: any Error)
}
