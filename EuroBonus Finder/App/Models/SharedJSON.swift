import SwiftUI

/// One of the App Group's JSON objects (see `SharedDefaultsKey`) as a value in
/// a view. Backed by `@AppStorage`, so the view updates when the app or the
/// extension writes it; `$value.field` gives bindings into it.
@propertyWrapper
struct SharedJSON<Value: Codable>: DynamicProperty {
    @AppStorage private var json: String
    private let fallback: Value

    init(_ key: String, default fallback: Value) {
        _json = AppStorage(wrappedValue: "", key, store: .shared)
        self.fallback = fallback
    }

    var wrappedValue: Value {
        get { JSONText.decode(Value.self, from: json) ?? fallback }
        nonmutating set { json = JSONText.encode(newValue) }
    }

    var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
