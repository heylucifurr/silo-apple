#if !os(macOS)
import AVFoundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Owns the muted, looping clip a Home hero plays behind its backdrop, and the
/// `AVPlayerLayer` host that draws it.
///
/// AVFoundation only, which the app already ships for playback — no new media
/// or UI library. The clip is the section card's `hero_video_url`; an absent or
/// failing URL simply leaves the backdrop alone (a hero never shows an error
/// for a trailer).
@MainActor
@Observable
final class HeroTrailerController {
    /// The clip pointed at, or nil when there is none.
    private(set) var urlString: String?
    private(set) var isMuted = true
    /// The player the layer host draws. Recreated per URL.
    @ObservationIgnored private(set) var player: AVPlayer?
    /// A clip that reached its end: the hero advances on it.
    var onFinished: (() -> Void)?

    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var failureObserver: NSObjectProtocol?
    /// A clip that failed to play: the controller stops trying until the URL
    /// changes. The hero shows the backdrop only.
    @ObservationIgnored private var failed = false

    /// Point the controller at a clip. The same URL is a no-op; a new URL
    /// replaces the player. An empty or nil URL tears the player down.
    func load(urlString: String?) {
        let trimmed = urlString?.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = (trimmed?.isEmpty == false) ? trimmed : nil
        guard next != self.urlString || (next == nil && player != nil) else { return }
        teardown()
        self.urlString = next
        failed = false
        guard let next, let url = URL(string: next) else { return }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = isMuted
        player.actionAtItemEnd = .pause
        player.preventsDisplaySleepDuringVideoPlayback = false
        self.player = player
        observeEnd(item)
        observeFailure(item)
    }

    func play() {
        guard let player, !failed else { return }
        player.play()
    }

    func pause() { player?.pause() }

    /// Play/pause for the tvOS Play/Pause remote command and any explicit
    /// control. A failure leaves the backdrop alone.
    func togglePlayback() {
        guard let player, !failed else { return }
        if player.rate == 0 { player.play() } else { player.pause() }
    }

    func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
    }

    func teardown() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        endObserver = nil
        failureObserver = nil
        player?.pause()
        player = nil
        urlString = nil
    }

    private func observeEnd(_ item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onFinished?() }
        }
    }

    private func observeFailure(_ item: AVPlayerItem) {
        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.failed = true
                self?.player?.pause()
            }
        }
    }
}

/// Draws a hero's trailer clip full-bleed behind its backdrop. The layer's
/// player is owned by `HeroTrailerController`, so the hero can pause, mute and
/// replace it without this view reaching into playback state.
struct HeroTrailerLayer: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> HeroTrailerHostView { HeroTrailerHostView() }

    func updateUIView(_ host: HeroTrailerHostView, context: Context) {
        if host.playerLayer.player !== player {
            host.playerLayer.player = player
        }
    }
}

final class HeroTrailerHostView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
#endif
