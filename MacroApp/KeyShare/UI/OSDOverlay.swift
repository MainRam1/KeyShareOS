import Cocoa
import SwiftUI

// MARK: - OSDOverlay

/// Floating overlay that briefly shows profile name on switch.
/// Uses `.nonactivatingPanel` so it won't steal focus.
final class OSDOverlay {

    static let shared = OSDOverlay()

    private let displayDuration: TimeInterval = 2.0
    private let fadeOutDuration: TimeInterval = 0.3
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    /// Show the OSD. Resets the timer if already visible.
    func show(profileName: String) {
        DispatchQueue.main.async { [weak self] in
            self?.showOnMain(profileName: profileName)
        }
    }

    func dismiss() {
        DispatchQueue.main.async { [weak self] in
            self?.tearDown()
        }
    }

    private func showOnMain(profileName: String) {
        // Cancel any pending dismiss
        dismissWorkItem?.cancel()

        // If panel exists, update content and reset timer
        if let existingPanel = panel {
            let hostingView = NSHostingView(rootView: OSDContentView(profileName: profileName))
            existingPanel.contentView = hostingView
            existingPanel.alphaValue = 1.0
            scheduleDismiss()
            return
        }

        // Create new panel
        let contentSize = NSSize(width: 280, height: 70)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false

        // Embed SwiftUI content
        let hostingView = NSHostingView(rootView: OSDContentView(profileName: profileName))
        panel.contentView = hostingView

        // Position: top-right of the main screen, below menu bar
        positionPanel(panel, size: contentSize)

        panel.alphaValue = 0.0
        panel.orderFrontRegardless()

        // Fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1.0
        }

        self.panel = panel
        scheduleDismiss()
    }

    private func positionPanel(_ panel: NSPanel, size: NSSize) {
        guard let screen = NSScreen.main else { return }

        let visibleFrame = screen.visibleFrame
        let padding: CGFloat = 20

        let x = visibleFrame.maxX - size.width - padding
        let y = visibleFrame.maxY - size.height - padding

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func scheduleDismiss() {
        dismissWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: workItem)
    }

    private func fadeOut() {
        guard let panel = panel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = fadeOutDuration
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.tearDown()
        })
    }

    private func tearDown() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - OSD SwiftUI Content

private struct OSDContentView: View {
    let profileName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Profile")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Text(profileName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }
}
