import SwiftUI

/// The launch splash: the brand logo, held while the app resolves its stored
/// session underneath.
///
/// Static by design. It replaced a baked keyframe animation whose generator is
/// gone, so there is nothing to draw frame by frame any more.
struct StartupSplashView: View {
    /// A floor, not the whole duration. `ContentView.isShowingStartupSplash`
    /// also keeps the splash up until `authState` leaves `.loading`, so a slow
    /// Keychain or a first-launch server probe extends it on its own.
    private static let minimumDuration: Duration = .milliseconds(1200)

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.weFlixBackground.ignoresSafeArea()

            GeometryReader { proxy in
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoWidth(in: proxy.size))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .ignoresSafeArea()
        }
        .accessibilityLabel("Loading weflix")
        .task {
            try? await Task.sleep(for: Self.minimumDuration)
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }

    /// The logo asset is 640×208. These keep it clear of the edges on a small
    /// phone and stop it looking lost on a TV, without a fixed size that would
    /// be wrong on one of them.
    private func logoWidth(in container: CGSize) -> CGFloat {
        #if os(tvOS)
        min(container.width * 0.30, 520)
        #elseif os(iOS)
        min(container.width * 0.56, 260)
        #else
        min(container.width * 0.40, 300)
        #endif
    }
}

extension EnvironmentValues {
    /// True while the startup splash covers the app being built underneath it.
    @Entry var isStartupSplashVisible = false
}
