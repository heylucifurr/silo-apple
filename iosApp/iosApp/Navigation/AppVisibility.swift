import Foundation

/// Which of the stock screens and rows this build shows.
///
/// This app is handed to people *using* one server, not running one, so the
/// rows that only serve a self-hoster, a developer, or a store reviewer are
/// off. Every flag is independent: flip one back to restore that row on its
/// own, without touching the others.
///
/// These are compile-time constants, so `if AppVisibility.x` blocks cost
/// nothing at runtime and the hidden branches are dropped by the optimiser.
enum AppVisibility {
    /// Settings ▸ Support — diagnostics capture, review, and reporting.
    static let showsDiagnostics = false

    /// Settings ▸ Connection ▸ Server — manage this device's connection, and
    /// the only route to the server list.
    static let showsServerSettings = false

    /// Settings ▸ Extra Features ▸ Show Audiobooks.
    static let showsAudiobooksToggle = false

    /// Settings ▸ About ▸ Privacy Policy, Acknowledgements, and Source Code.
    ///
    /// These three are also the only in-app route to the third-party licence
    /// notices — AetherEngine and FFmpeg ship under the LGPL — and to the AGPL
    /// source offer. Turning them off is a licensing decision, not just a
    /// visual one: keep them unless those notices live somewhere else.
    static let showsLegalRows = false

    /// The Settings search field.
    static let showsSettingsSearch = false

    /// "Switch Server" in the profile menu.
    static let showsSwitchServer = false

    /// "Change server" on the profile picker, in the footer beside Sign out.
    static let showsChangeServer = false
}
