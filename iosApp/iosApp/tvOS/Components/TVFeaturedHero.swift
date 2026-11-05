#if os(tvOS)
import SwiftUI

/// A Home row the server flags as featured, rendered as the full-width hero
/// across the top of Home on tvOS.
///
/// One composite focus owner (see `docs/tvos-focus.md`): the whole hero is the
/// single focus target, so the remote drives it without competing focus writes.
/// Left/Right move between the row's titles, Select opens the title's page,
/// Play/Pause toggles the trailer clip, Up returns to the top menu, and Down
/// hands focus into the rows below.
struct TVFeaturedHero: View {
    let section: ResolvedSection
    /// The shell's content focus hand-down token.
    var focusRequest: Int = 0
    /// Bumped when focus returns from the rows below; the hero reclaims it.
    var reclaimRequest: Int = 0
    /// True while the top menu owns focus; the hero must not pull focus out of
    /// the bar.
    var isTopMenuFocused: Bool = false
    /// Up at the hero's top boundary returns focus to the top menu.
    var onMoveUp: (() -> Void)? = nil
    /// Down hands focus into the rows below the hero.
    var onMoveDown: (() -> Void)? = nil
    /// Select opens the title's page.
    var onSelect: (SectionItem) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    @State private var index = 0
    @State private var trailer = HeroTrailerController()
    /// The viewer pressed Play/Pause: autoplay holds off until they resume.
    @State private var pausedByViewer = false
    /// The clip has drawn a frame, so its layer can fade in over the backdrop.
    @State private var trailerHasFrame = false
    /// The logo that has finished loading; until then the name shows as text.
    @State private var loadedLogoURL: String?

    private var items: [SectionItem] { section.items }
    private var item: SectionItem? {
        guard !items.isEmpty else { return nil }
        return items[min(index, items.count - 1)]
    }

    /// The clip may run: focused, motion allowed, and not paused by the viewer.
    /// tvOS is mains-powered, so Low Power Mode never applies.
    private var playsTrailer: Bool {
        isFocused && !reduceMotion && !pausedByViewer && trailer.urlString != nil
    }

    /// The clip is running and has a frame, so it takes over from the backdrop.
    private var showsTrailer: Bool { playsTrailer && trailerHasFrame }

    var body: some View {
        if let item {
            ZStack(alignment: .bottomLeading) {
                backdrop(for: item)
                trailerLayer
                scrim
                content(for: item)
                if showsTrailer {
                    muteIndicator
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(WeFlixTheme.smallPadding)
                }
            }
            .frame(maxWidth: .infinity)
            // A large share of the screen, so the rows below stay in view.
            .containerRelativeFrame(.vertical) { length, _ in
                max(360, length * WeFlixTheme.Skyline.heroHeightFraction)
            }
            .clipped()
            .background(Color.weFlixPageCanvas)
            .contentShape(Rectangle())
            .focusable(true)
            .focused($isFocused)
            // The hero draws its own focus treatment (a brighter scrim and a
            // framed pill), so the system halo would double it.
            .focusEffectDisabled()
            .onMoveCommand { direction in
                switch direction {
                case .left: step(-1)
                case .right: step(1)
                case .up: onMoveUp?()
                case .down: onMoveDown?()
                default: break
                }
            }
            .onPlayPauseCommand {
                pausedByViewer.toggle()
                if playsTrailer { trailer.play() } else { trailer.pause() }
            }
            .onTapGesture { onSelect(item) }
            .onChange(of: playsTrailer) { _, playing in
                if playing { trailer.play() } else { trailer.pause() }
            }
            .onChange(of: index) { _, _ in
                loadedLogoURL = nil
                pausedByViewer = false
                trailerHasFrame = false
                trailer.load(urlString: item.heroVideoUrl)
                if playsTrailer { trailer.play() }
            }
            .task(id: item.contentId) {
                trailer.onFinished = { advance() }
                trailer.load(urlString: item.heroVideoUrl)
                if playsTrailer { trailer.play() } else { trailer.pause() }
            }
            .task(id: AdvanceTrigger(
                index: index,
                mode: advanceMode,
                count: items.count,
                isFocused: isFocused,
                pausedByViewer: pausedByViewer
            )) {
                await advanceAfterDelay()
            }
            .task(id: ClaimKey(focusRequest: focusRequest, reclaim: reclaimRequest)) {
                guard !isTopMenuFocused else { return }
                // Let the outgoing content's focus teardown commit first.
                await Task.yield()
                guard !Task.isCancelled, !isTopMenuFocused else { return }
                isFocused = true
            }
            .onDisappear { trailer.pause() }
            .onChange(of: items.map(\.contentId)) { _, ids in
                if index >= ids.count { index = max(0, ids.count - 1) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Featured, \(item.title)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Select for more info. Swipe left or right for another title.")
        }
    }

    // MARK: - Layers

    @ViewBuilder
    private func backdrop(for entry: SectionItem) -> some View {
        if let art = HomeHeroContent.backdrop(entry) {
            AsyncImageView(url: art.url, thumbhash: art.thumbhash, contentMode: .fill)
                .episodeSpoilerBlur(EpisodeSpoilerPreferences.shared.settings.hidesImage(for: entry))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(entry.contentId)
                .transition(.opacity)
                .clipped()
        } else {
            Color.weFlixSurfaceElevated
        }
    }

    private var trailerLayer: some View {
        HeroTrailerLayer(
            player: reduceMotion ? nil : trailer.player,
            onFirstFrame: { trailerHasFrame = true }
        )
        .id(trailer.urlString ?? "no-clip")
        .opacity(showsTrailer ? 1 : 0)
        .animation(.easeInOut(duration: Self.trailerCrossfade), value: showsTrailer)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Dissolves the hero's bottom into the page over its lower 45%, so the
    /// clip and the backdrop meet the rows below with no hard edge.
    private var scrim: some View {
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

    /// The clip's mute state, in the phone hero's control style. It is not a
    /// focus target: the hero is one composite focus owner and the Siri Remote
    /// has no mute button, so this reports the clip's state and Play/Pause keeps
    /// owning playback.
    private var muteIndicator: some View {
        Image(systemName: trailer.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.45)))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    // MARK: - Content

    private func content(for item: SectionItem) -> some View {
        VStack(alignment: .leading, spacing: WeFlixTheme.spacing) {
            Text("Featured — No. \(Self.twoDigit(index + 1))")
                .font(.weFlixCaption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(Color.weFlixSecondaryText)

            title(for: item)

            if let metadata = HomeHeroContent.metadataLine(item) {
                Text(metadata)
                    .font(.weFlixCaption.weight(.semibold))
                    .foregroundStyle(Color.weFlixOnSurface)
                    .lineLimit(1)
            }

            if let badge = HomeHeroContent.comingSoonBadge(item) {
                ComingSoonChip(text: badge, isFocused: isFocused)
            }

            if let overview = item.overview?.heroNonEmpty {
                Text(overview)
                    .font(.weFlixBody)
                    .foregroundStyle(Color.weFlixSecondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            footer
        }
        .frame(maxWidth: WeFlixTheme.Skyline.marqueeContentWidth, alignment: .leading)
        .padding(.leading, WeFlixTheme.safePadding)
        .padding(.bottom, WeFlixTheme.padding)
        .animation(.easeInOut(duration: WeFlixTheme.slowDuration), value: index)
    }

    @ViewBuilder
    private func title(for item: SectionItem) -> some View {
        let name = Text(item.title)
            .font(.weFlixTitle)
            .foregroundStyle(Color.weFlixOnSurface)
            .lineLimit(2)
            .minimumScaleFactor(0.7)

        if TitleArtPreferences.shared.showsTitleArt,
           let logoURL = item.logoUrl?.heroNonEmpty {
            let isLoaded = loadedLogoURL == logoURL
            ZStack(alignment: .bottomLeading) {
                name.opacity(isLoaded ? 0 : 1)
                HeroTitleLogo(url: logoURL, size: Self.logoSize) {
                    loadedLogoURL = logoURL
                }
                .opacity(isLoaded ? 1 : 0)
                .id(logoURL)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.title)
            .accessibilityAddTraits(.isHeader)
        } else {
            name.accessibilityAddTraits(.isHeader)
        }
    }

    /// Page dots and the "01 / 05" counter for the row.
    private var footer: some View {
        HStack(alignment: .center, spacing: WeFlixTheme.spacing) {
            if items.count > 1 {
                HStack(spacing: 8) {
                    ForEach(items.indices, id: \.self) { offset in
                        Circle()
                            .fill(offset == index ? Color.weFlixPrimary : Color.weFlixSecondaryText)
                            .frame(width: 8, height: 8)
                    }
                }
                .accessibilityHidden(true)

                Text("\(Self.twoDigit(index + 1)) / \(Self.twoDigit(items.count))")
                    .font(.weFlixCaption)
                    .monospacedDigit()
                    .foregroundStyle(Color.weFlixSecondaryText)
                    .accessibilityLabel("Slide \(index + 1) of \(items.count)")
            }
        }
        .padding(.top, WeFlixTheme.smallPadding)
    }

    // MARK: - Behaviour

    private struct AdvanceTrigger: Equatable {
        let index: Int
        let mode: AdvanceMode
        let count: Int
        let isFocused: Bool
        let pausedByViewer: Bool
    }

    /// How the hero decides to move on.
    private enum AdvanceMode: Equatable {
        /// A clip is on screen: the hero waits for the clip itself to end, and
        /// the end-of-item notification calls `advance()`.
        case clipPlaying
        /// A clip belongs to the card but has not drawn a frame yet: a bounded
        /// wait, so a clip that never loads cannot hang the carousel.
        case clipStarting
        /// No clip to play (none, or Reduce Motion): the hero turns on a timer.
        case noClip
    }

    private var advanceMode: AdvanceMode {
        guard trailer.urlString != nil, !reduceMotion, !pausedByViewer else { return .noClip }
        return trailerHasFrame ? .clipPlaying : .clipStarting
    }

    /// Re-claims focus on entry and whenever the rows hand it back up.
    private struct ClaimKey: Equatable {
        let focusRequest: Int
        let reclaim: Int
    }

    /// The clip plays to its own end on the focused card; a card with no clip
    /// turns on a timer instead. A viewer who paused the clip decides when the
    /// hero moves on.
    private func advanceAfterDelay() async {
        guard items.count > 1, isFocused, !pausedByViewer else { return }
        switch advanceMode {
        case .clipPlaying:
            // The clip's own end moves the hero on; no timer competes with it.
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
        withAnimation(.easeInOut(duration: WeFlixTheme.slowDuration)) {
            index = (index + 1) % items.count
        }
    }

    private func step(_ delta: Int) {
        let count = items.count
        guard count > 1 else { return }
        withAnimation(.easeInOut(duration: WeFlixTheme.slowDuration)) {
            index = (index + delta + count) % count
        }
    }

    // MARK: - Metrics

    private static let noClipAdvanceSeconds: Double = 8
    private static let clipStartTimeout: Double = 20
    private static let trailerCrossfade: Double = 0.3
    private static let logoSize = CGSize(width: 340, height: 140)

    static func twoDigit(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

/// The "Coming soon · <date>" chip on a curated title the library lacks. It
/// brightens while the hero holds focus.
private struct ComingSoonChip: View {
    let text: String
    let isFocused: Bool

    var body: some View {
        Text(text)
            .font(.weFlixCaption.weight(.semibold))
            .foregroundStyle(Color.weFlixOnSurface)
            .padding(.horizontal, WeFlixTheme.spacing)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.weFlixChromeSelectedFill))
            .overlay(Capsule().stroke(isFocused ? Color.weFlixPrimary : Color.weFlixChromeSelectedBorder))
            .accessibilityLabel(text)
    }
}
#endif
