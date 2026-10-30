import SwiftUI

struct WeFlixWordmarkView: View {
    var width: CGFloat = 150
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image("WeFlixWordmark")
                .resizable()
                .scaledToFit()
                .frame(width: width)
                .accessibilityLabel("weflix")

            if let subtitle {
                Text(subtitle)
                    .font(.weFlixCaption)
                    .foregroundColor(.weFlixSecondaryText)
                    .tracking(2)
            }
        }
    }
}
