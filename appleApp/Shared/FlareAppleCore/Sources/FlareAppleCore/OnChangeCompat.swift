import SwiftUI

public extension View {
    /// Compatibility bridge for the iOS 17 two-value `onChange` overload.
    /// iOS 15 exposes only the new value, so callers that do not consume the
    /// previous value receive the current value for both arguments.
    func onChangeCompat<Value: Equatable>(
        of value: Value,
        _ action: @escaping (Value, Value) -> Void
    ) -> some View {
        onChange(of: value) { newValue in
            action(newValue, newValue)
        }
    }

    /// Compatibility bridge for the iOS 17 `initial:` overload.
    /// The initial callback runs when the view appears; later callbacks use
    /// the iOS 15 one-value overload.
    func onChangeCompat<Value: Equatable>(
        of value: Value,
        initial: Bool,
        _ action: @escaping (Value, Value) -> Void
    ) -> some View {
        onAppear {
            if initial {
                action(value, value)
            }
        }
        .onChange(of: value) { newValue in
            action(newValue, newValue)
        }
    }
}
