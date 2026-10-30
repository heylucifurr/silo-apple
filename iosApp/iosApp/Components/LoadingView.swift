import SwiftUI

/// Full-screen loading indicator.
struct LoadingView: View {
    var message: String? = nil
    var usesPageBackground = false

    var body: some View {
        ZStack {
            if usesPageBackground {
                WeFlixPageBackdrop()
            } else {
                Color.weFlixBackground.ignoresSafeArea()
            }

            VStack(spacing: 20) {
                WeFlixWordmarkView(width: 132)

                ProgressView()
                    .tint(.weFlixOnSurface)
                    .scaleEffect(1.2)

                if let message {
                    Text(message)
                        .font(.weFlixCaption)
                        .foregroundColor(.weFlixSecondaryText)
                }
            }
        }
    }
}
