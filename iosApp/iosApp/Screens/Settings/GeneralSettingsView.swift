#if !os(tvOS)
import SwiftUI

/// Device-local startup preferences that do not belong to playback or
/// interface customization.
struct GeneralSettingsView: View {
    @State private var launchPreferences = ProfileLaunchPreferences.shared
    @StateObject private var advisoryAgePreference = AdvisoryAgePreferenceStore.shared

    var body: some View {
        List {
            profileSection
            if advisoryAgePreference.isSupported {
                advisoryAgeSection
            }
        }
        .settingsListChrome()
        .navigationTitle("General")
        .weFlixNavigationTitleDisplayMode(.inline)
        .weFlixToolbarColorSchemeDark()
        .task { await advisoryAgePreference.refresh() }
    }

    private var profileSection: some View {
        Section {
            Picker("Profile Selection", selection: $launchPreferences.behavior) {
                ForEach(ProfileLaunchBehavior.allCases) { behavior in
                    Text(behavior.title)
                        .accessibilityHint(behavior.standardDescription)
                        .tag(behavior)
                }
            }
            .foregroundStyle(Color.weFlixOnSurface)
            .settingsPickerStyle()
            .accessibilityValue(launchPreferences.behavior.title)
            .accessibilityHint(launchPreferences.behavior.standardDescription)
        } header: {
            Text("Profiles")
                .foregroundStyle(Color.weFlixSecondaryText)
        } footer: {
            Text(launchPreferences.behavior.standardDescription)
                .foregroundStyle(Color.weFlixSecondaryText)
        }
        .listRowBackground(Color.weFlixGroupedCell)
    }

    private var advisoryAgeSection: some View {
        Section {
            Toggle(
                "Show Advisory Age",
                isOn: Binding(
                    get: { advisoryAgePreference.showsAdvisoryAge },
                    set: { value in
                        Task { await advisoryAgePreference.setShowsAdvisoryAge(value) }
                    }
                )
            )
            .foregroundStyle(Color.weFlixOnSurface)
            .tint(.weFlixSwitchOn)
            .disabled(advisoryAgePreference.isSaving)
        } header: {
            Text("Ratings")
                .foregroundStyle(Color.weFlixSecondaryText)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Show a suggested minimum viewer age, such as Common Sense Media’s, on movie and show details. This does not change what the profile may watch.")
                if let writeError = advisoryAgePreference.writeError {
                    Text(writeError)
                }
            }
            .foregroundStyle(Color.weFlixSecondaryText)
        }
        .listRowBackground(Color.weFlixGroupedCell)
    }
}
#endif
