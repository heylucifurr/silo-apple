import SwiftUI

extension Font {
    #if os(tvOS)

    // tvOS is viewed from ~10 feet away, so all typography is scaled up
    // roughly 2.3x from iOS. tvOS has no user text-size preference, so fixed
    // point sizes are used to keep proportions stable across screens.

    /// Large screen titles — "Discover", "TV Shows" (48pt bold)
    static let weFlixTitle = Font.system(size: 48, weight: .bold)

    /// Section headlines — "Continue Watching" (36pt semibold)
    static let weFlixHeadline = Font.system(size: 36, weight: .semibold)

    /// Card titles and subheadlines (28pt semibold)
    static let weFlixSubheadline = Font.system(size: 28, weight: .semibold)

    /// Movie/series names directly beneath artwork. Kept quieter than general
    /// subheadlines so dense eight-across rows remain readable rather than
    /// visually shouting over the posters.
    static let weFlixPosterTitle = Font.system(size: 24, weight: .medium)

    /// Year, episode title, and other secondary poster-card metadata.
    static let weFlixPosterMetadata = Font.system(size: 20, weight: .regular)

    /// Body text — descriptions, synopses (26pt regular)
    static let weFlixBody = Font.system(size: 26)

    /// Captions and metadata (22pt regular)
    static let weFlixCaption = Font.system(size: 22, weight: .regular)

    /// Smallest text — badges, episode numbers, tab labels (20pt regular)
    static let weFlixSmall = Font.system(size: 20, weight: .regular)

    /// Numeric displays like PINs (64pt monospaced bold)
    static let weFlixPIN = Font.system(size: 64, weight: .bold, design: .monospaced)

    #else

    #if os(macOS)
    // macOS text styles run about two points smaller than iOS, which left
    // page and row headings undersized in a desktop window. The Mac steps
    // both up one style.

    /// Large screen titles — "Discover", "TV Shows"
    static let weFlixTitle = Font.title2.bold()

    /// Section headlines — "Continue Watching"
    static let weFlixHeadline = Font.title3.weight(.semibold)

    /// Title of Home's featured hero.
    static let weFlixHeroTitle = Font.system(size: 34, weight: .bold)
    #else
    /// Large screen titles — "Discover", "TV Shows"
    static let weFlixTitle = Font.title3.bold()

    /// Section headlines — "Continue Watching"
    static let weFlixHeadline = Font.headline
    #endif

    /// Card titles and subheadlines
    static let weFlixSubheadline = Font.subheadline.bold()

    /// Body text — descriptions, synopses
    static let weFlixBody = Font.body

    /// Captions and metadata
    static let weFlixCaption = Font.caption

    /// Smallest text — badges, episode numbers, tab labels
    static let weFlixSmall = Font.caption2

    /// Numeric displays like PINs
    static let weFlixPIN = Font.largeTitle.monospaced().bold()

    #endif

    // MARK: - Card captions

    /// Title under a poster or still card. The Mac's cards are larger than
    /// the phone's, and its text styles smaller, so it steps the caption up.
    static var weFlixCardTitle: Font {
        #if os(macOS)
        .body.weight(.semibold)
        #else
        weFlixSubheadline
        #endif
    }

    /// Year, episode, or time-left line under a card title.
    static var weFlixCardMetadata: Font {
        #if os(macOS)
        .callout
        #else
        weFlixCaption
        #endif
    }
}

extension View {
    /// A system font with an exact point size that still follows Dynamic Type.
    /// `size` is the point size at the default (Large) text size; other sizes
    /// scale it the way `textStyle` scales, and an enclosing
    /// `.dynamicTypeSize(_:)` limit applies. Pick the text style whose default
    /// size is closest to `size`. Use this where a design needs a point size
    /// between the semantic styles; prefer a semantic font otherwise.
    func weFlixScaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design? = nil,
        relativeTo textStyle: Font.TextStyle
    ) -> some View {
        modifier(WeFlixScaledSystemFont(size: size, weight: weight, design: design, textStyle: textStyle))
    }
}

private struct WeFlixScaledSystemFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design?

    init(size: CGFloat, weight: Font.Weight, design: Font.Design?, textStyle: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}
