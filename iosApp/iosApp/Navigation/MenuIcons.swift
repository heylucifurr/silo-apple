import SwiftUI

/// Menu icons that ship as bundled artwork instead of SF Symbols.
///
/// The bottom bar, the sidebar, the status column and the interface-customization
/// list all carry icons as *names*. Most are SF Symbol names; these three are
/// asset names. `Image(systemName:)` draws nothing for an asset name, and
/// `Image(_:)` draws nothing for a symbol, so every one of those renderers
/// resolves through `menuIcon(_:)` instead of assuming which kind it holds.
enum MenuIconAsset {
    static let movies = "TabMovies"
    static let shows = "TabShows"
    static let anime = "TabAnime"

    static let all: Set<String> = [movies, shows, anime]
}

/// Draws a menu icon name: the bundled asset when the name is one, an SF Symbol
/// otherwise.
///
/// The bundled artwork is declared as a template in the asset catalogue, so it
/// tints with the row like a symbol does, in both the selected and the
/// unselected state. Both kinds are sized by the caller; a symbol follows the
/// font it inherits, while the artwork is a 128×128 square that scales to the
/// frame it is given.
func menuIcon(_ name: String) -> Image {
    MenuIconAsset.all.contains(name) ? Image(name) : Image(systemName: name)
}

/// The icon names a library shows in the menu.
///
/// A library that is one media type takes that type's artwork, so Movies and
/// Series stop reading as two identical stacks. Mixed libraries keep their own
/// glyph, and anything the profile only partly matches keeps the generic stack —
/// the same rule the Mac sidebar has always used, shared so the bottom bar and
/// the sidebar cannot disagree.
///
/// Anime is matched **by name**. The server has no anime library type, so
/// `WeFlixMediaType` cannot tell one apart, and an anime library reports itself
/// as mixed or series. Keeping the rule here means a server-side type can
/// replace it without hunting call sites.
func menuIconNames(for library: Library) -> (icon: String, selectedIcon: String) {
    if isAnimeLibrary(library) {
        return (MenuIconAsset.anime, MenuIconAsset.anime)
    }
    if library.isMixedLibrary {
        return (library.navigationIcon, library.selectedNavigationIcon)
    }
    let categories: [PrimaryMenuBuiltin] = [.movies, .series, .audiobooks]
    if let category = categories.first(where: {
        libraryMatchesPrimaryMenuCategory(library, category: $0)
    }) {
        return (category.navigationIcon, category.navigationIcon)
    }
    return (library.navigationIcon, library.selectedNavigationIcon)
}

/// Whether a library reads as anime. Case- and whitespace-insensitive, because
/// the name is whatever the server admin typed.
private func isAnimeLibrary(_ library: Library) -> Bool {
    library.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "anime"
}
