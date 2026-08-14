import SwiftUI

/// Lightweight runtime-safe screen used only by the release iOS 15 compatibility build.
/// Complex modern views remain available in normal builds and are not type-checked into
/// this compatibility IPA, preventing unavailable SwiftUI APIs from reaching iOS 15.
struct IOS15CompatibilityScreen: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.title3.weight(.semibold))
            Text("This page is unavailable in the iOS 15 compatibility build.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button("Back") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle(title)
    }
}
