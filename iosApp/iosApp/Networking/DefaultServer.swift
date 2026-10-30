import Foundation

/// The server this build ships for.
///
/// A self-hosted deployment that hands the app to people who will never run a
/// server of their own sets the address here once, so nobody has to type one.
/// With a non-empty `host`:
///
/// - `ContentView.connectDefaultServerIfNeeded()` makes this server active on a
///   first launch that has nothing saved, and initial resolution then lands on
///   sign-in instead of server setup.
/// - `ServerSetupViewModel` starts its address field on `host`, so the setup
///   screen is still one tap away when the server is unreachable.
///
/// An empty `host` restores the stock behaviour: every launch starts at server
/// setup with an empty address field.
enum DefaultServer {
    /// Bare host, no scheme and no trailing slash.
    static let host = "weflix.me"

    /// The address the app connects to and stores in the registry. HTTPS: the
    /// registry rejects a plain-HTTP entry that is not on the LAN.
    static let url = "https://\(host)"
}
