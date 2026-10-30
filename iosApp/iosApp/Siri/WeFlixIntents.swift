#if os(iOS) || os(tvOS)
import AppIntents

/// Siri's in-app search. On Apple TV, a short press of the Siri button while
/// WeFlix is open, or "Search in weflix", routes the spoken term here.
///
/// tvOS has no `.system.search` schema macro, so both platforms conform to
/// `ShowInAppSearchResultsIntent` directly. The protocol already runs the
/// intent in the app's foreground process.
struct SearchInWeFlixIntent: ShowInAppSearchResultsIntent {
    static let title: LocalizedStringResource = "Search weflix"
    static let description = IntentDescription("Opens Search in weflix with your search term.")
    static let searchScopes: [StringSearchScope] = [.general, .movies, .tv]

    @Parameter(title: "Search Term", requestValueDialog: "What do you want to search for?")
    var criteria: StringSearchCriteria

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = SiriSearchLink.url(term: criteria.term) {
            WeFlixDeepLinkCoordinator.shared.receive(url)
        }
        return .result()
    }
}

struct WeFlixAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SearchInWeFlixIntent(),
            phrases: [
                "Search \(.applicationName)",
                "Search in \(.applicationName)",
                "Find something on \(.applicationName)",
            ],
            shortTitle: "Search",
            systemImageName: "magnifyingglass"
        )
    }
}
#endif
