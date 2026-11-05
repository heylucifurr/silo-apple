#if os(iOS)
import SwiftUI

/// A Home row the server flags as featured, drawn as the Prime-style carousel
/// card at the top of Home.
///
/// The card is inset from the page edges with rounded top corners, its media
/// (backdrop, then a muted clip of the title's trailer) scaled to fill and
/// centre-cropped, and its bottom third faded into the page so the card has no
/// visible bottom edge. The title, badges, runtime, year and release date sit
/// in that fade; the page dots and the mute control are the only controls.
///
/// There is no call to action: a tap anywhere on the card opens the title.
/// Autoplay pauses off-screen, in the background, on Low Power Mode and with
/// Reduce Motion on; with no clip (or a failed one) the backdrop alone shows and
/// no error is raised.
struct PhoneHomeHero: View {
    let section: ResolvedSection
    /// Width of the tappable card. The caller insets it from the page edges and
    /// caps it for a tablet; the height follows from the card's aspect.
    var cardWidth: CGFloat
    /// Opens the title's page (item detail, or the title page for a coming-soon
    /// title).
    var onOpen: (SectionItem) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var trailer = HeroTrailerController()
    /// The clip has drawn a frame, so its layer can fade in over the backdrop.
    @State private var trailerHasFrame = false
    @State private var isOnScreen = true
    @State private var isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    /// The logo that has finished loading. Until a title's logo is in, its name
    /// is shown as text, so the card is never untitled.
    @State private var loadedLogoURL: String?

    private var items: [SectionItem] { section.items }
    private var item: SectionItem? {
        guard !items.isEmpty else { return nil }
        return items[min(index, items.count - 1)]
    }
    private var cardHeight: CGFloat { (cardWidth * Self.aspect).rounded() }

    /// The clip may run: on screen, in the foreground, not on Low Power Mode,
    /// and with motion allowed.
    private var autoplaysTrailer: Bool {
        isOnScreen && scenePhase == .active && !isLowPower && !reduceMotion
            && trailer.urlString != nil
    }
    /// The clip is running and has a frame, so it takes over from the backdrop.
    private var showsTrailer: Bool { autoplaysTrailer && trailerHasFrame }

    var body: some View {
        if let item {
            ZStack {
                backdrops
                trailerLayer
                bottomFade
                content(for: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                dots
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, Self.dotsBottomInset - Self.dotsTapPadding)
                if showsMuteButton {
                    muteButton
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(Self.cornerInset)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(Self.cardShape)
            .contentShape(Self.cardShape)
            // No call to action: the whole card is the target. The dots and the
            // mute control keep their own taps.
            .onTapGesture { onOpen(item) }
            // Off-screen, background, Low Power, and Reduce Motion all stop the
            // clip and the advance timer.
            .onChange(of: autoplaysTrailer) { _, playing in
                if playing { trailer.play() } else { trailer.pause() }
            }
            .onChange(of: index) { _, _ in
                loadedLogoURL = nil
                trailerHasFrame = false
                trailer.load(urlString: item.heroVideoUrl)
                if autoplaysTrailer { trailer.play() }
            }
            .onScrollVisibilityChange(threshold: 0.1) { isOnScreen = $0 }
            .onChange(of: scenePhase) { _, _ in
                if autoplaysTrailer { trailer.play() } else { trailer.pause() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .task(id: item.contentId) {
                trailer.onFinished = { advance() }
                trailer.load(urlString: item.heroVideoUrl)
                if autoplaysTrailer { trailer.play() } else { trailer.pause() }
            }
            .task(id: AdvanceTrigger(
                index: index,
                mode: advanceMode,
                count: items.count,
                isOnScreen: isOnScreen,
                isActive: scenePhase == .active
            )) {
                await advanceAfterDelay()
            }
            .onDisappear { trailer.pause() }
            .onChange(of: items.map(\.contentId)) { _, ids in
                // A reload can shorten the row; keep the card on a title that
                // still exists.
                if index >= ids.count { index = max(0, ids.count - 1) }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Featured, \(item.title)")
            .accessibilityAction(named: Text("Show details")) { onOpen(item) }
        }
    }

    // MARK: - Layers

    /// One paged backdrop per title. Swiping this pages the card; the text layer
    /// follows `index`.
    private var backdrops: some View {
        TabView(selection: $index) {
            ForEach(Array(items.enumerated()), id: \.element.contentId) { offset, entry in
                backdropArt(for: entry)
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func backdropArt(for entry: SectionItem) -> some View {
        if let art = HomeHeroContent.backdrop(entry) {
            // Fills and centre-crops: no letterbox bars.
            AsyncImageView(url: art.url, thumbhash: art.thumbhash, contentMode: .fill)
                .episodeSpoilerBlur(EpisodeSpoilerPreferences.shared.settings.hidesImage(for: entry))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            Color.weFlixSurfaceElevated
        }
    }

    /// The muted clip, over the backdrop. The backdrop stays until the clip has
    /// a frame to draw, then this crossfades in over it.
    private var trailerLayer: some View {
        HeroTrailerLayer(
            player: reduceMotion ? nil : trailer.player,
            onFirstFrame: { trailerHasFrame = true }
        )
        .id(trailer.urlString ?? "no-clip")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(showsTrailer ? 1 : 0)
        .animation(.easeInOut(duration: Self.trailerCrossfade), value: showsTrailer)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Dissolves the card's bottom into the page: transparent over the top 55%,
    /// then the page colour, so the card has no visible bottom edge.
    private var bottomFade: some View {
        LinearGradient(
            stops: [
                .init(color: Color.weFlixPageCanvas.opacity(0), location: 0.55),
                .init(color: Color.weFlixPageCanvas, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Content

    private func content(for item: SectionItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            title(for: item)
            metadataRow(for: item)
                .padding(.top, 8)
            if let date = HomeHeroContent.releaseDateText(item.releaseDate) {
                dateLine(date)
                    .padding(.top, 6)
            }
        }
        // Leaves room for the dots, which sit 14 below the date line.
        .padding(.bottom, Self.dotsBottomInset + Self.dotHeight + Self.dotsGap)
        .padding(.horizontal, Self.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: WeFlixTheme.slowDuration), value: index)
    }

    /// The title logo where the server sends one, else the name as text. Both
    /// sit inside the fade, with no strip behind them.
    @ViewBuilder
    private func title(for item: SectionItem) -> some View {
        let maxWidth = cardWidth * Self.titleWidthFraction
        let name = Text(item.title)
            .weFlixScaledFont(size: 24, weight: .bold, relativeTo: .title2)
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .shadow(color: .black.opacity(0.6), radius: 6, y: 2)

        if TitleArtPreferences.shared.showsTitleArt,
           let logoURL = item.logoUrl?.heroNonEmpty {
            let isLoaded = loadedLogoURL == logoURL
            ZStack(alignment: .bottomLeading) {
                name.opacity(isLoaded ? 0 : 1)
                HeroTitleLogo(url: logoURL, size: CGSize(width: maxWidth, height: Self.titleMaxHeight)) {
                    loadedLogoURL = logoURL
                }
                .opacity(isLoaded ? 1 : 0)
                .id(logoURL)
            }
            .frame(maxWidth: maxWidth, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.title)
            .accessibilityAddTraits(.isHeader)
        } else {
            name
                .frame(maxWidth: maxWidth, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// The badge and metadata line: a white COMING SOON pill, a grey rating pill,
    /// then runtime, year and the first genre, separated by spacing alone.
    @ViewBuilder
    private func metadataRow(for item: SectionItem) -> some View {
        HStack(spacing: Self.metadataSpacing) {
            // Only a curated title the library lacks carries the badge; an owned
            // one is an ordinary catalog card.
            if item.isComingSoon {
                Text("COMING SOON")
                    .weFlixScaledFont(size: 13, weight: .bold, relativeTo: .caption)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white))
                    .accessibilityLabel("Coming soon")
            }

            if let certification = item.contentRating?.heroNonEmpty {
                Text(certification)
                    .weFlixScaledFont(size: 13, weight: .bold, relativeTo: .caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Self.ratingPill))
            }

            if let runtime = MediaTextFormatting.runtime(minutes: item.runtime) {
                Text(runtime)
                    .weFlixScaledFont(size: 15, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(.white)
            }

            if let year = item.year, year > 0 {
                Text(String(year))
                    .weFlixScaledFont(size: 15, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(Self.secondaryText)
            }

            if let genre = item.genres?.first?.heroNonEmpty {
                Text(genre)
                    .weFlixScaledFont(size: 15, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(Self.secondaryText)
            }
        }
        .lineLimit(1)
        .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
    }

    /// The release date under the metadata row: a calendar glyph and the date.
    private func dateLine(_ date: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .weFlixScaledFont(size: 15, relativeTo: .subheadline)
                .foregroundStyle(.white)
            Text(date)
                .weFlixScaledFont(size: 15, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Release date \(date)")
    }

    // MARK: - Controls

    /// Centred page dots: the active slide is a wide white pill, the rest small
    /// grey circles. When the row holds more titles than the dots can show, the
    /// window's end dots shrink to hint at the rest.
    private var dots: some View {
        HStack(spacing: Self.dotsGap) {
            ForEach(visibleDots) { dot in
                Button { select(dot.index) } label: {
                    Capsule()
                        .fill(dot.isActive ? Color.white : Color.white.opacity(0.4))
                        .frame(
                            width: dot.isActive ? Self.activeDotWidth : dot.size,
                            height: dot.isActive ? Self.dotHeight : dot.size
                        )
                        .frame(height: Self.dotHeight + 2 * Self.dotsTapPadding)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.weFlixFlat)
                .accessibilityLabel("Slide \(dot.index + 1) of \(items.count)")
                .accessibilityAddTraits(dot.isActive ? .isSelected : [])
            }
        }
        .animation(.easeInOut(duration: 0.2), value: index)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Slides")
    }

    private struct Dot: Identifiable {
        let index: Int
        let isActive: Bool
        let size: CGFloat
        var id: Int { index }
    }

    /// The dots on show: one per title up to `maxVisibleDots`, else a window of
    /// that size centred on the active slide. An end of a windowed run is 4pt.
    private var visibleDots: [Dot] {
        let count = items.count
        guard count > 0 else { return [] }
        var start = 0
        var end = count - 1
        if count > Self.maxVisibleDots {
            start = min(max(0, index - Self.maxVisibleDots / 2), count - Self.maxVisibleDots)
            end = start + Self.maxVisibleDots - 1
        }
        let windowed = count > Self.maxVisibleDots
        return (start...end).map { offset in
            let isEdge = windowed && (offset == start || offset == end)
            return Dot(index: offset, isActive: offset == index, size: isEdge ? 4 : Self.dotHeight)
        }
    }

    /// Top-right of the card, fully inside it. Shown only while the clip runs.
    private var showsMuteButton: Bool { autoplaysTrailer }

    private var muteButton: some View {
        Button { trailer.toggleMute() } label: {
            Image(systemName: trailer.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Self.muteButtonSize, height: Self.muteButtonSize)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.45)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                // A 44pt touch target around a 40pt button.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.weFlixFlat)
        .accessibilityLabel(trailer.isMuted ? "Unmute trailer" : "Mute trailer")
    }

    // MARK: - Behaviour

    private struct AdvanceTrigger: Equatable {
        let index: Int
        let mode: AdvanceMode
        /// Any change to the row's titles restarts the timer, so a pending
        /// advance never acts on titles that have been replaced.
        let count: Int
        let isOnScreen: Bool
        let isActive: Bool
    }

    /// How the card decides to move on.
    private enum AdvanceMode: Equatable {
        /// A clip is on screen: the card waits for the clip itself to end, and
        /// the end-of-item notification calls `advance()`.
        case clipPlaying
        /// A clip exists but has not drawn a frame: a bounded wait, so a clip
        /// that never loads cannot hang the carousel.
        case clipStarting
        /// No clip to play (none, or Reduce Motion): the card turns on a timer.
        case noClip
    }

    private var advanceMode: AdvanceMode {
        guard trailer.urlString != nil, !reduceMotion else { return .noClip }
        return trailerHasFrame ? .clipPlaying : .clipStarting
    }

    private func advanceAfterDelay() async {
        guard items.count > 1, isOnScreen, scenePhase == .active else { return }
        switch advanceMode {
        case .clipPlaying:
            // The clip's own end moves the card on; no timer competes with it.
            return
        case .clipStarting:
            try? await Task.sleep(for: .seconds(Self.clipStartTimeout))
        case .noClip:
            try? await Task.sleep(for: .seconds(Self.noClipAdvanceSeconds))
        }
        guard !Task.isCancelled else { return }
        advance()
    }

    private func advance() {
        guard items.count > 1 else { return }
        select((index + 1) % items.count)
    }

    private func select(_ offset: Int) {
        guard offset != index else { return }
        withAnimation(.easeInOut(duration: WeFlixTheme.slowDuration)) {
            index = offset
        }
    }

    // MARK: - Metrics

    /// The card's height as a share of its width.
    private static let aspect: CGFloat = 0.78
    /// The page's horizontal inset, so the card sits 16 from each edge. The
    /// caller subtracts it from the page width to size the card.
    static let pageInset: CGFloat = 16
    private static let contentInset: CGFloat = 16
    /// Corner inset for the mute control.
    private static let cornerInset: CGFloat = 12
    private static let titleWidthFraction: CGFloat = 0.6
    private static let titleMaxHeight: CGFloat = 64
    private static let metadataSpacing: CGFloat = 8
    private static let dotHeight: CGFloat = 6
    private static let activeDotWidth: CGFloat = 18
    private static let dotsGap: CGFloat = 6
    /// Half the extra height a dot's tap target adds above and below its mark,
    /// so the visible dot still sits `dotsBottomInset` from the card's bottom.
    private static let dotsTapPadding: CGFloat = 9
    private static let dotsBottomInset: CGFloat = 16
    private static let maxVisibleDots = 5
    private static let muteButtonSize: CGFloat = 40
    /// A card with no clip turns after this; a card whose clip is still loading
    /// gives up on it after `clipStartTimeout`. A card whose clip is playing is
    /// left alone until the clip ends.
    private static let noClipAdvanceSeconds: Double = 8
    private static let clipStartTimeout: Double = 20
    private static let trailerCrossfade: Double = 0.3

    private static let ratingPill = Color(hex: "#3A3A3A")
    private static let secondaryText = Color.white.opacity(0.6)

    /// Rounded at the top, square at the bottom, so the fade can bleed the card
    /// into the page.
    private static let cardShape = UnevenRoundedRectangle(
        topLeadingRadius: 20,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: 20
    )

    static func twoDigit(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
#endif
