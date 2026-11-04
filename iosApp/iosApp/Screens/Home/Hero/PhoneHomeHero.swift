#if os(iOS)
import SwiftUI

/// A Home row the server flags as featured, rendered as a hero carousel at the
/// top of Home: a large backdrop with a muted autoplay clip of the title's
/// trailer, its logo, a metadata line and, for a title the library does not own,
/// a "Coming soon · <date>" badge instead of Play.
///
/// Swipe between the row's titles, tap a dot, or let it advance on its own
/// (~8s, or when the clip ends). Autoplay pauses off-screen, in the background,
/// on Low Power Mode, and with Reduce Motion on; with no clip (or a failed one)
/// the backdrop alone shows and no error is raised.
struct PhoneHomeHero: View {
    let section: ResolvedSection
    /// The hero band's height. Measured from the page so the hero can bleed to
    /// the very top and still leave the next row peeking, as Prime's does.
    var height: CGFloat
    /// Opens the title's page (item detail, or the title page for a coming-soon
    /// title). The hero carries no buttons — a tap anywhere on it does this,
    /// as Prime's mobile hero does.
    var onOpen: (SectionItem) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var trailer = HeroTrailerController()
    @State private var isOnScreen = true
    @State private var isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    /// The logo that has finished loading. Until a title's logo is in, its name
    /// is shown as text, so the hero is never untitled.
    @State private var loadedLogoURL: String?

    private var items: [SectionItem] { section.items }
    private var item: SectionItem? {
        guard !items.isEmpty else { return nil }
        return items[min(index, items.count - 1)]
    }

    /// The clip may run: on screen, in the foreground, not on Low Power Mode,
    /// and with motion allowed.
    private var autoplaysTrailer: Bool {
        isOnScreen && scenePhase == .active && !isLowPower && !reduceMotion
            && trailer.urlString != nil
    }

    var body: some View {
        if let item {
            ZStack(alignment: .bottomLeading) {
                backdrops
                trailerLayer
                scrim
                content(for: item)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .background(Color.weFlixPageCanvas)
            .contentShape(Rectangle())
            // No call to action: the whole hero is the target. The page dots and
            // the mute control keep their own taps.
            .onTapGesture { onOpen(item) }
            // Off-screen, background, Low Power, and Reduce Motion all stop the
            // clip and the advance timer.
            .onChange(of: autoplaysTrailer) { _, playing in
                if playing { trailer.play() } else { trailer.pause() }
            }
            .onChange(of: index) { _, _ in
                loadedLogoURL = nil
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
            .task(id: AdvanceTrigger(index: index, autoplays: autoplaysTrailer, count: items.count)) {
                await advanceAfterDelay()
            }
            .onDisappear { trailer.pause() }
            .onChange(of: items.map(\.contentId)) { _, ids in
                // A reload can shorten the row; keep the slide on a title that
                // still exists.
                if index >= ids.count { index = max(0, ids.count - 1) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Featured, \(item.title)")
            .accessibilityAction(named: Text("Show details")) { onOpen(item) }
        }
    }

    // MARK: - Layers

    /// One paged backdrop per title. Swiping this pages the hero; the text layer
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
            AsyncImageView(url: art.url, thumbhash: art.thumbhash, contentMode: .fill)
                .episodeSpoilerBlur(EpisodeSpoilerPreferences.shared.settings.hidesImage(for: entry))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            Color.weFlixSurfaceElevated
        }
    }

    /// The muted clip, over the backdrop. Absent while Reduce Motion is on, so
    /// the still shows through.
    private var trailerLayer: some View {
        HeroTrailerLayer(player: reduceMotion ? nil : trailer.player)
            .id(trailer.urlString ?? "no-clip")
            .opacity(autoplaysTrailer ? 1 : 0)
            .animation(.easeInOut(duration: WeFlixTheme.slowDuration), value: autoplaysTrailer)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Fades the artwork into the page canvas so the text stays legible, plus a
    /// gentle top fade that keeps the floating header readable over bright art.
    private var scrim: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.35), location: 0),
                    .init(color: .clear, location: 0.26),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.26),
                    .init(color: Color.weFlixPageCanvas.opacity(0.55), location: 0.64),
                    .init(color: Color.weFlixPageCanvas, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Content

    private func content(for item: SectionItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured — No. \(Self.twoDigit(index + 1))")
                .font(.weFlixCaption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(Color.weFlixSecondaryText)

            title(for: item)

            if let metadata = HomeHeroContent.metadataLine(item) {
                Text(metadata)
                    .font(.weFlixCaption.weight(.semibold))
                    .foregroundStyle(Color.weFlixOnSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if let badge = HomeHeroContent.comingSoonBadge(item) {
                ComingSoonBadge(text: badge)
            }

            if let overview = item.overview?.heroNonEmpty {
                Text(overview)
                    .font(.weFlixBody)
                    .foregroundStyle(Color.weFlixSecondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    // The last line of the synopsis fades into the artwork, as
                    // Prime's does.
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.8),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            footer(for: item)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .frame(maxWidth: 560, alignment: .leading)
        .padding(.horizontal, HomeFeedMetrics.gutter)
        .padding(.bottom, WeFlixTheme.largePadding)
        .animation(.easeInOut(duration: WeFlixTheme.slowDuration), value: index)
    }

    @ViewBuilder
    private func title(for item: SectionItem) -> some View {
        let name = Text(item.title)
            .weFlixScaledFont(size: 34, weight: .bold, relativeTo: .largeTitle)
            .foregroundStyle(Color.weFlixOnSurface)
            .lineLimit(2)
            .minimumScaleFactor(0.6)

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

    /// Page dots plus the mute toggle for the clip.
    private func footer(for item: SectionItem) -> some View {
        HStack(alignment: .center, spacing: WeFlixTheme.spacing) {
            if items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(items.indices, id: \.self) { offset in
                        Button {
                            withAnimation(.easeInOut(duration: WeFlixTheme.slowDuration)) {
                                index = offset
                            }
                        } label: {
                            Circle()
                                .fill(offset == index ? Color.white : Color.white.opacity(0.35))
                                .frame(
                                    width: offset == index ? 8 : 6,
                                    height: offset == index ? 8 : 6
                                )
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.weFlixFlat)
                        .accessibilityLabel("Slide \(offset + 1) of \(items.count)")
                        .accessibilityAddTraits(offset == index ? .isSelected : [])
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Slides")
            }

            Spacer(minLength: 0)

            // Shown only while the clip is running, as Prime's is: no clip, no
            // control.
            if autoplaysTrailer {
                Button { trailer.toggleMute() } label: {
                    Image(systemName: trailer.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.weFlixBody.weight(.semibold))
                        .foregroundStyle(Color.weFlixOnSurface)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.weFlixChromeSelectedFill))
                        .overlay(Circle().stroke(Color.weFlixChromeSelectedBorder))
                        .contentShape(Circle())
                }
                .buttonStyle(.weFlixFlat)
                .accessibilityLabel(trailer.isMuted ? "Unmute trailer" : "Mute trailer")
            }
        }
        .padding(.top, WeFlixTheme.smallPadding)
    }

    // MARK: - Behaviour

    private struct AdvanceTrigger: Equatable {
        let index: Int
        let autoplays: Bool
        /// Any change to the row's titles restarts the timer, so a pending
        /// advance never acts on titles that have been replaced.
        let count: Int
    }

    private func advanceAfterDelay() async {
        guard autoplaysTrailer, items.count > 1 else { return }
        try? await Task.sleep(for: .seconds(Self.advanceSeconds))
        guard !Task.isCancelled else { return }
        advance()
    }

    private func advance() {
        guard items.count > 1 else { return }
        withAnimation(.easeInOut(duration: WeFlixTheme.slowDuration)) {
            index = (index + 1) % items.count
        }
    }

    // MARK: - Metrics

    /// Share of the page height the hero fills. Prime's mobile hero is nearly
    /// full screen, so the next row only peeks at the bottom.
    static let heightFraction: CGFloat = 0.9
    private static let advanceSeconds: Double = 8
    private static let logoSize = CGSize(width: 340, height: 150)

    static func twoDigit(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

/// The "Coming soon · <date>" capsule on a curated title the library lacks.
private struct ComingSoonBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.weFlixCaption.weight(.semibold))
            .foregroundStyle(Color.weFlixOnSurface)
            .padding(.horizontal, WeFlixTheme.spacing)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.weFlixChromeSelectedFill))
            .overlay(Capsule().stroke(Color.weFlixChromeSelectedBorder))
            .accessibilityLabel(text)
    }
}
#endif
