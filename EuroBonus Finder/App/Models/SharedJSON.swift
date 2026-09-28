import SwiftUI

/// A Codable value kept as one JSON object in the App Group (see
/// `SharedDefaultsKey`). Backed by `@AppStorage`, so views update when the
/// app or the extension writes it; `$value.field` gives bindings into it.
@propertyWrapper
struct SharedJSON<Value: Codable>: DynamicProperty {
    @AppStorage private var json: String
    private let fallback: Value

    init(_ key: String, default fallback: Value) {
        _json = AppStorage(wrappedValue: "", key, store: .shared)
        self.fallback = fallback
    }

    var wrappedValue: Value {
        get {
            guard let data = json.data(using: .utf8),
                  let value = try? JSONDecoder().decode(Value.self, from: data)
            else { return fallback }
            return value
        }
        nonmutating set {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            json = (try? encoder.encode(newValue)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        }
    }

    var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
