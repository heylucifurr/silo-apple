import SwiftUI

/// The shared right-hand action cluster used at the top of tab-root screens:
/// Search, the iOS TV remote control, and a profile-avatar menu with
/// Settings / Switch Profile / Sign Out. Every root page renders the same
/// three controls so the header reads identically across Home, Libraries,
/// For You, and Calendar.
///
/// Each tab renders its own leading content (e.g. library selector on the
/// Libraries tab, the wordmark on Home) and places this view on the
/// trailing side of a single `HStack` row.
struct TabTopBarActions: View {
    let onSearch: () -> Void
    let onOpenSettings: () -> Void
    /// Opens Downloads. The menu row only renders when the profile can
    /// download, so the closure is inert otherwise.
    let onOpenDownloads: () -> Void
    let onSwitchProfile: () -> Void
    let onSwitchServer: () -> Void
    let onSignOut: () -> Void
    /// Vertical in the iPhone Duo's status column (`StatusColumnBar`).
    var axis: Axis = .horizontal

    /// Shared session cache so switching pages never refetches or flashes
    /// the avatar fallback.
    private let profileStore = CurrentProfileStore.shared
    #if os(iOS)
    @Environment(WeFlixControlClient.self) private var weFlixControl
    @State private var isShowingControlPicker = false
    @Environment(\.statusColumn) private var statusColumn
    #endif

    var body: some View {
        #if os(macOS)
        // The Mac sidebar carries Search and the profile menu.
        EmptyView()
        #else
        if showsActions {
            actions
        } else {
            // Holds the header row at its usual height so the page below
            // doesn't move up.
            Color.clear
                .frame(width: 0, height: WeFlixTheme.topBarIconHitSize)
                .accessibilityHidden(true)
        }
        #endif
    }

    #if !os(macOS)
    /// The header copy steps aside while the iPhone Duo's status column
    /// shows the same actions.
    private var showsActions: Bool {
        #if os(iOS)
        axis == .vertical || statusColumn == nil
        #else
        true
        #endif
    }

    private var actions: some View {
        // Icons spaced evenly. Order is fixed: Search, Remote (iOS), Profile.
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: WeFlixTheme.topBarIconSpacing))
            : AnyLayout(VStackLayout(spacing: 6))
        return layout {
            TopBarIconButton(
                systemImage: "magnifyingglass",
                accessibilityLabel: "Search",
                action: onSearch
            )
            #if os(iOS)
            WeFlixControlModeButton(controller: weFlixControl) {
                isShowingControlPicker = true
            }
            #endif
            ProfileAvatarMenu(
                profile: profileStore.profile,
                onOpenSettings: onOpenSettings,
                onOpenDownloads: onOpenDownloads,
                onSwitchProfile: onSwitchProfile,
                onSwitchServer: onSwitchServer,
                onSignOut: onSignOut
            )
        }
        #if os(iOS)
        .sheet(isPresented: $isShowingControlPicker) {
            WeFlixControlTargetPickerView(request: nil, controller: weFlixControl)
        }
        #endif
        // No-op once cached; covers a page shown before the session-level
        // load finished.
        .task { await profileStore.refresh() }
    }
    #endif
}

/// Plain icon button used for utility actions (Search) in the top bar.
/// The 44×44 frame keeps a comfortable tap target while the glyph itself
/// stays small and chrome-free.
private struct TopBarIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.weFlixOnSurface)
                .frame(width: WeFlixTheme.topBarIconHitSize, height: WeFlixTheme.topBarIconHitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Profile avatar opening the account menu (Watch Party, Requests, Settings,
/// Switch Profile, Switch Server, Sign Out).
struct ProfileAvatarMenu: View {
    @Environment(AppRouter.self) private var router
    let profile: UserProfile?
    /// Shows the profile name beside the avatar as a full-width row, for the
    /// Mac sidebar. The top-bar cluster keeps the avatar alone.
    var showsName = false
    let onOpenSettings: () -> Void
    let onOpenDownloads: () -> Void
    let onSwitchProfile: () -> Void
    let onSwitchServer: () -> Void
    let onSignOut: () -> Void

    /// Capability-gated: the Downloads row exists only when the profile can
    /// download at all. Requests needs no row here — it is a tab.
    private var downloadsEnabled: Bool {
        DownloadManager.shared.downloadsEnabled
    }

    private var avatarSize: CGFloat {
        #if os(macOS)
        WeFlixTheme.macSidebarAvatarSize
        #else
        30
        #endif
    }

    /// The default avatar fill is as dark as the Mac sidebar, so the row
    /// there uses the lighter tile grey to keep the circle visible.
    private var avatarFill: Color {
        showsName ? .weFlixIconTile : .weFlixSurfaceVariant
    }

    var body: some View {
        Menu {
            #if os(iOS) || os(tvOS)
            if WatchPartyEntry.isAvailable {
                Button(WatchPartySession.shared.isEngaged ? "Return to Watch Party" : "Watch Party", systemImage: "person.3") { router.navigate(to: .watchParty) }
            }
            #endif
            if downloadsEnabled {
                Button {
                    onOpenDownloads()
                } label: {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }

                Divider()
            }

            Button {
                onOpenSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Divider()

            Button {
                onSwitchProfile()
            } label: {
                Label("Switch Profile", systemImage: "person.2")
            }
            if AppVisibility.showsSwitchServer {
                Button {
                    onSwitchServer()
                } label: {
                    Label("Switch Server", systemImage: "server.rack")
                }
            }
            Button(role: .destructive) {
                onSignOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            HStack(spacing: WeFlixTheme.smallPadding) {
                ProfileAvatarView(
                    avatar: profile?.avatarEmoji,
                    imageUrl: profile?.avatarImageUrl,
                    name: profile?.name ?? "",
                    size: avatarSize,
                    backgroundColor: avatarFill
                )
                .frame(
                    width: showsName ? nil : WeFlixTheme.topBarIconHitSize,
                    height: WeFlixTheme.topBarIconHitSize
                )
                if showsName {
                    Text(profile?.name ?? "")
                        .font(.weFlixHeadline)
                        .foregroundStyle(Color.weFlixOnSurface)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .contentShape(Rectangle())
        }
        #if os(macOS)
        // The borderless style flattens a Mac menu label to bare text; the
        // plain button style keeps the avatar-and-name row.
        .menuStyle(.button)
        .buttonStyle(.plain)
        #else
        .menuStyle(.borderlessButton)
        #endif
        .accessibilityLabel("Profile menu")
    }
}
