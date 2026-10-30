#if os(iOS)
import SwiftUI

struct WeFlixControlModeButton: View {
    let controller: WeFlixControlClient
    let onChooseTarget: () -> Void

    var body: some View {
        if controller.remotePlaybackEngaged {
            Menu {
                Button { controller.showRemoteControl() } label: {
                    Label("Remote Control", systemImage: "slider.horizontal.3")
                }
                Button { onChooseTarget() } label: {
                    Label("Choose TV", systemImage: "tv")
                }
                Divider()
                Button(role: .destructive) { controller.disconnect() } label: {
                    Label("Turn Off Control Mode", systemImage: "tv.slash")
                }
            } label: {
                buttonLabel(isActive: true)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("TV control mode")
            .accessibilityValue("Active")
        } else {
            Button(action: onChooseTarget) {
                buttonLabel(isActive: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remote Control")
        }
    }

    private func buttonLabel(isActive: Bool) -> some View {
        Image(systemName: isActive ? "appletvremote.gen4.fill" : "appletvremote.gen4")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.weFlixOnSurface)
            .frame(width: WeFlixTheme.topBarIconHitSize, height: WeFlixTheme.topBarIconHitSize)
            .contentShape(Rectangle())
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 20) {
        WeFlixControlModeButton(controller: WeFlixControlClient(), onChooseTarget: {})
    }
    .padding()
    .background(Color.weFlixBackground)
}
#endif
#endif
