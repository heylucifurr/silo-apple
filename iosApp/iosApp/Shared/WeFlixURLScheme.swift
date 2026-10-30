import Foundation

/// The app's custom URL scheme, shared with the Android clients and the
/// server's web pages.
///
/// WeFlix servers are self-hosted on arbitrary domains, so universal links
/// cannot reach the app; `weflix://` is the one route in that works for every
/// deployment. Links that name a server carry it as a `server` query item.
///
/// Earlier builds emitted `silo://` and, before that, `continuum://`. The
/// system and the server may still hold those links — Top Shelf items,
/// delivered notifications, Live Activities, and push payloads the server
/// built before the rename — so both schemes stay registered and are accepted
/// as aliases.
enum WeFlixURLScheme {
    /// The scheme this build emits for links it creates.
    static let current = "weflix"
    /// The scheme this client emitted before the rename. Servers running an
    /// older release still send `silo://` deep links.
    static let legacySilo = "silo"
    /// The scheme the client emitted before the Silo rename.
    static let legacy = "continuum"

    static func isAppURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == current || scheme == legacySilo || scheme == legacy
    }
}
