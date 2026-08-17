import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController {
    private var pollTask: Task<Void, Never>?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Beru"
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
        window.contentView = NSHostingView(rootView: OnboardingView(controller: self))
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startPolling()
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                // Stop polling if the user closed the window without granting;
                // otherwise this loop would keep waking the process forever.
                guard self.window?.isVisible == true else { break }
                if Permissions.isAccessibilityTrusted() {
                    self.window?.close()
                    break
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    deinit {
        pollTask?.cancel()
    }
}

struct OnboardingView: View {
    weak var controller: OnboardingWindowController?

    var body: some View {
        VStack(spacing: 20) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("Beru needs Accessibility access")
                .font(.title2.bold())

            Text("Beru reads and replaces selected text in other apps so it can enhance or correct it. Grant Accessibility access in System Settings, then this window will close automatically. After that, open Settings from the menu bar and choose a provider.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Selected text is sent only to the provider you configure. Local history is off until you turn it on in Settings.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Open System Settings") {
                Permissions.requestAccessibilityIfNeeded()
                Permissions.openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(width: 420, height: 380)
    }
}
