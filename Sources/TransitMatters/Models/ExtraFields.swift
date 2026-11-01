import OpenAPIRuntime

// Some entries have fields the spec only describes in prose, such as `fleet_mix_<type>`. The generated
// types keep those in `additionalProperties`; these read them back out.
extension OpenAPIObjectContainer {
    /// The number under `key`, whether the JSON wrote it as an integer or a decimal.
    func number(_ key: String) -> Double? {
        Self.double(value[key] ?? nil)
    }

    /// The numbers under keys of the form `{prefix}{name}{suffix}`, keyed by `name`.
    func numbers(prefix: String, suffix: String = "") -> [String: Double] {
        var numbers: [String: Double] = [:]
        for (key, item) in value
        where key.hasPrefix(prefix) && key.hasSuffix(suffix) && key.count > prefix.count + suffix.count {
            numbers[String(key.dropFirst(prefix.count).dropLast(suffix.count))] = Self.double(item)
        }
        return numbers
    }

    private static func double(_ item: (any Sendable)?) -> Double? {
        switch item {
        case let number as Int: Double(number)
        case let number as Double: number
        default: nil
        }
    }
}
