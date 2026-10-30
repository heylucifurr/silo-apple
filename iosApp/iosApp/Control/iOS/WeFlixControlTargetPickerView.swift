#if os(iOS)
import SwiftUI

struct WeFlixControlTargetPickerView: View {
    let request: WeFlixControlPlaybackRequest?
    let controller: WeFlixControlClient

    @State private var browser = WeFlixControlBrowser()
    @State private var searchTimedOut = false
    /// Read once: the picker lives for one search.
    @State private var rememberedRoku = WeFlixControlClient.rememberedRoku
    private let pairingKeys = WeFlixControlPairingKeys()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if !displayedTargets.isEmpty {
                    foundList
                } else if searchTimedOut {
                    emptyState
                } else {
                    searchingState
                }
            }
            .weFlixSheetBackground()
            .statusColumnSheetWidth()
            .navigationTitle("Remote Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                browser.start()
                try? await Task.sleep(for: .seconds(8))
                searchTimedOut = true
            }
            .onDisappear { browser.stop() }
        }
        .preferredColorScheme(.dark)
        .presentationDetents(displayedTargets.count > 3 ? [.medium, .large] : [.medium])
    }

    private var searchingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Searching for weflix TVs…")
                .font(.headline)
                .foregroundStyle(Color.weFlixSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No weflix TVs Found",
            systemImage: "tv",
            description: Text(missingRokuHint
                ?? "TVs on this server appear here while weflix is open on them. On a Roku, open weflix with the Roku remote.")
        )
    }

    /// The phone can't open WeFlix on a Roku, so when the Roku it last
    /// controlled hasn't turned up by the end of the search, the picker says
    /// how to bring it back.
    private var missingRokuHint: String? {
        guard searchTimedOut, let roku = rememberedRoku, !browser.found.contains(where: { $0.id == roku.id }) else { return nil }
        return "Don't see \(roku.name)? Open weflix on your Roku."
    }

    private var foundList: some View {
        List(displayedTargets) { target in
            Button {
                Task {
                    if let request {
                        await controller.play(on: target, request: request)
                    } else {
                        await controller.connect(to: target)
                    }
                    dismiss()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "tv")
                        .font(.title3)
                        .foregroundStyle(Color.weFlixOnSurface)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.weFlixChromeRestingFill))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(target.name).font(.headline)
                        if target.transport == .sealed, pairingKeys.key(for: target) == nil {
                            Text("Scan this Roku's pairing code to connect")
                                .font(.subheadline)
                                .foregroundStyle(Color.weFlixSecondaryText)
                        } else if request != nil, target.protocolVersion < 2 {
                            Text("Update weflix on this TV to use your profile")
                                .font(.subheadline)
                                .foregroundStyle(Color.weFlixSecondaryText)
                        } else if target.isPlaying {
                            Text("Playing now")
                                .font(.subheadline)
                                .foregroundStyle(Color.weFlixPrimary)
                        } else if let serverName = target.serverName {
                            Text(target.targetsActiveServer
                                 ? serverName
                                 : "Will temporarily use your server")
                                .font(.subheadline)
                                .foregroundStyle(Color.weFlixSecondaryText)
                        }
                    }

                    Spacer()

                    if controller.isConnecting && controller.activeTarget?.id == target.id {
                        ProgressView().accessibilityLabel("Connecting")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(request != nil && target.protocolVersion < 2)
            .listRowBackground(Color.weFlixSurface)
        }
        .safeAreaInset(edge: .bottom) {
            if let missingRokuHint {
                Text(missingRokuHint)
                    .font(.footnote)
                    .foregroundStyle(Color.weFlixSecondaryText)
                    .padding(.bottom, 12)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var displayedTargets: [WeFlixControlTarget] {
        guard request == nil else { return browser.found }
        guard ServerRegistry.shared.activeServer != nil else { return [] }
        return browser.found.filter(\.targetsActiveServer)
    }
}

#if DEBUG
#Preview("Searching") {
    WeFlixControlTargetPickerView(request: nil, controller: WeFlixControlClient())
}
#endif
#endif
