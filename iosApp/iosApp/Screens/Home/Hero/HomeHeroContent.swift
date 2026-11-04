#if !os(macOS)
import Foundation

/// Presentation helpers shared by the iOS/iPadOS and tvOS Home heroes, so the
/// two layouts read identically. Pure formatting and item lookup — no layout.
enum HomeHeroContent {
    /// The artwork a hero draws behind its text: an episode's series backdrop
    /// (its own backdrop is usually a small still), else its backdrop, else its
    /// poster. Nil when the item carries no artwork at all.
    static func backdrop(_ item: SectionItem) -> (url: String, thumbhash: String?)? {
        if let seriesBackdrop = item.episodeSeriesBackdrop {
            return seriesBackdrop
        }
        if let url = item.backdropUrl?.heroNonEmpty {
            return (url, item.backdropThumbhash)
        }
        if let url = item.posterUrl?.heroNonEmpty {
            return (url, item.posterThumbhash)
        }
        return nil
    }

    /// The hero's metadata track, as Prime shows it: "2026 · 1h 57m · Mystery ·
    /// Thriller · R", skipping whatever the item does not carry. For a
    /// coming-soon title the year is its release year.
    ///
    /// Ratings are deliberately left out — the hero keeps year, runtime, up to
    /// two genres and the certification only.
    static func metadataLine(_ item: SectionItem) -> String? {
        var parts: [String] = []
        if let year = item.year, year > 0 { parts.append(String(year)) }
        if let runtime = MediaTextFormatting.runtime(minutes: item.runtime) { parts.append(runtime) }
        parts.append(contentsOf: (item.genres ?? []).prefix(2))
        if let contentRating = item.contentRating?.heroNonEmpty { parts.append(contentRating) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The badge for a curated title the library does not own:
    /// "Coming soon · 16 Dec 2026" while its snapshot date is still ahead,
    /// else "Coming soon". Nil for an ordinary card.
    ///
    /// An unowned curated title stays Coming soon past its date on the server
    /// too, so a past date is dropped rather than shown under the badge.
    static func comingSoonBadge(_ item: SectionItem) -> String? {
        guard item.isComingSoon else { return nil }
        guard let date = upcomingReleaseDate(item.releaseDate) else { return "Coming soon" }
        return "Coming soon · \(date)"
    }

    /// A `YYYY-MM-DD` release date formatted as "16 Dec 2026", or nil when it
    /// is missing, unparseable, or already past.
    static func upcomingReleaseDate(_ raw: String?) -> String? {
        guard let value = raw.flatMap({ $0.heroNonEmpty }) else { return nil }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: value), date > Date() else { return nil }
        let out = DateFormatter()
        out.locale = Locale.current
        out.timeZone = TimeZone(identifier: "UTC")
        out.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return out.string(from: date)
    }
}

extension String {
    /// The string, or nil when it is empty — a one-step guard for the many
    /// optional artwork and rating members a card may carry as "".
    var heroNonEmpty: String? { isEmpty ? nil : self }
}
#endif
