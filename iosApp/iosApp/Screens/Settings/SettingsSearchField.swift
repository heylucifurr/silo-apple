#if os(iOS)
import SwiftUI

/// Capsule search field in the system search-bar style, placed in the
/// Settings list between the profile and the first section.
struct SettingsSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.weFlixSecondaryText)
                .accessibilityHidden(true)

            TextField("Search", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Color.weFlixOnSurface)
                .accessibilityLabel("Search settings")

            if !text.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") {
                    text = ""
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(Color.weFlixSecondaryText)
                .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Color.weFlixGroupedCell, in: Capsule())
    }
}
#endif
