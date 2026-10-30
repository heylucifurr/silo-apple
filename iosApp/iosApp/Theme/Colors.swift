import SwiftUI

extension Color {
    // MARK: - Core Palette (OLED dark)

    /// Pure black background (#000000)
    static let weFlixBackground = Color(hex: "#000000")

    /// Barely-visible surface (#0A0A0A)
    static let weFlixSurface = Color(hex: "#0A0A0A")

    /// Surface variant for containers (#0E0F12)
    static let weFlixSurfaceVariant = Color(hex: "#0E0F12")

    /// Surface for elevated containers like episode cards (#15171C)
    static let weFlixSurfaceElevated = Color(hex: "#15171C")

    /// Primary interactive color — same as text (monochrome UI)
    static let weFlixPrimary = Color(hex: "#EDEDED")

    /// Primary text color (#EDEDED)
    static let weFlixOnSurface = Color(hex: "#EDEDED")

    /// Track of an on switch. The monochrome palette would make an on switch
    /// a white knob on a white track, so switches keep the system's dark-mode
    /// green; every other control stays monochrome.
    static let weFlixSwitchOn = Color(hex: "#30D158")

    /// Row background of an inset-grouped list — the system's dark-mode
    /// secondary grouped background, shared by Settings and Downloads.
    static let weFlixGroupedCell = Color(hex: "#1C1C1E")

    /// Graphite fill behind Settings row icons.
    static let weFlixIconTile = Color(hex: "#3A3A3C")

    /// Orange sampled from the canonical WeFlix wordmark artwork. Reserved for
    /// branded moments such as the storage breakdown.
    static let weFlixBrandOrange = Color(hex: "#FD7403")

    /// Blue sampled from the WeFlix wordmark.
    static let weFlixBrandBlue = Color(hex: "#0034FB")

    /// Red sampled from the WeFlix wordmark.
    static let weFlixBrandRed = Color(hex: "#F50B4F")

    /// Deep blue field behind the mark on the app icon.
    static let weFlixIconField = Color(hex: "#010D9F")

    /// Muted/secondary text — primary at 60% opacity (#99EDEDED)
    static let weFlixSecondaryText = Color(hex: "#99EDEDED")

    /// Error red (#B00020)
    static let weFlixError = Color(hex: "#B00020")

    /// Success green
    static let weFlixSuccess = Color.green

    /// Warning amber (ratings stars)
    static let weFlixWarning = Color(hex: "#FFC107")

    // MARK: - Skyline chrome (guide §4)

    /// Selected-but-unfocused tab/pill capsule fill — `chrome.selected`, white @ 14%
    static let weFlixChromeSelectedFill = Color.white.opacity(0.14)

    /// Inner border of the selected capsule — white @ 10%
    static let weFlixChromeSelectedBorder = Color.white.opacity(0.10)

    /// Resting pill/chip fill — `chrome.unfocused-bg`, white @ 7%
    static let weFlixChromeRestingFill = Color.white.opacity(0.07)

    /// Hairline border on resting pills/chips — white @ 9%
    static let weFlixChromeRestingBorder = Color.white.opacity(0.09)

    /// Anchored dropdown panel fill — `glass.strong`, #16171B @ 86% over blur
    static let weFlixGlassStrong = Color(hex: "#16171B").opacity(0.86)


    // MARK: - Request status dots

    /// The requests UI keeps chips monochrome; these tint only the small
    /// status dot (and match the web app's ribbon palette so both clients
    /// speak one status language). Pending — amber.
    static let requestAmber = Color(hex: "#F59E0B")

    /// Approved / queued / downloading — sky.
    static let requestSky = Color(hex: "#38BDF8")

    /// Completed / in library — emerald.
    static let requestEmerald = Color(hex: "#34D399")

    /// Declined / failed — rose.
    static let requestRose = Color(hex: "#FB7185")

    // MARK: - Semantic Aliases

    /// Outline/border color — white at 12%
    static let weFlixOutline = Color.white.opacity(0.12)

    /// Divider/separator line color — white at 12%
    static let weFlixDivider = Color.white.opacity(0.12)

    /// Disabled control tint
    static let weFlixDisabled = Color(hex: "#4B5563")

    // MARK: - First-run status

    /// Error text and outlines on first-run surfaces.
    static let weFlixErrorInk = Color(hex: "#FF6961")

    /// Attention status (unreachable server, setup needs a look).
    static let weFlixStatusWarning = Color(hex: "#F4C869")

    /// Live/OK status; the same green as `weFlixSwitchOn`.
    static let weFlixStatusLive = weFlixSwitchOn

    /// Text-field caret tint.
    static let weFlixFieldTint = Color(hex: "#0A84FF")

    #if os(macOS)
    /// Mac page canvas: one flat charcoal behind every signed-in page.
    static let weFlixPageCanvas = Color(hex: "#1A1A1C")

    /// Mac sidebar surface, a shade darker than the page canvas so the two
    /// regions read as separate without a border.
    static let weFlixSidebarCanvas = Color(hex: "#121214")
    #else
    /// Signed-in iOS page canvas behind `WeFlixPageBackdrop`'s washes.
    static let weFlixPageCanvas = Color(hex: "#111111")
    #endif
}
