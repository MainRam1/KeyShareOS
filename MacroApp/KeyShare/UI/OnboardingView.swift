import ApplicationServices
import Cocoa
import Combine
import SwiftUI

// MARK: - OnboardingWindowController

/// Shows on first launch or when Accessibility permission is missing.
final class OnboardingWindowController {

    private var window: NSWindow?
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    static var shouldShowOnboarding: Bool {
        let completed = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        let hasPerm = Permissions.isAccessibilityGranted()
        return !completed || !hasPerm
    }

    func showWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingView = OnboardingView(onComplete: { [weak self] in
            self?.complete()
        })

        let hostingController = NSHostingController(rootView: onboardingView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Welcome to KeyShare"
        newWindow.contentViewController = hostingController
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: Self.hasCompletedOnboardingKey)
        window?.close()
        window = nil
    }
}

// MARK: - OnboardingView

/// Walks the user through granting Accessibility permission.
struct OnboardingView: View {

    let onComplete: () -> Void

    @StateObject private var permissionState = PermissionPollState()

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Welcome to KeyShare")
                .font(.title)
                .fontWeight(.bold)

            Text("KeyShare needs Accessibility permission to send keyboard shortcuts and control your Mac.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 380)

            // Permission status
            HStack(spacing: 8) {
                Image(systemName: permissionState.isGranted
                    ? "checkmark.circle.fill"
                    : "exclamationmark.triangle.fill")
                    .foregroundColor(permissionState.isGranted ? .green : .orange)
                    .font(.system(size: 16))

                Text(permissionState.isGranted
                    ? "Accessibility permission granted"
                    : "Accessibility permission required")
                    .font(.callout)
                    .foregroundColor(permissionState.isGranted ? .green : .orange)
            }
            .padding(.vertical, 4)

            // Instructions
            if !permissionState.isGranted {
                VStack(alignment: .leading, spacing: 8) {
                    instructionRow(step: 1, text: "Click \"Open System Settings\" below")
                    instructionRow(step: 2, text: "Find KeyShare in the list")
                    instructionRow(step: 3, text: "Toggle the switch to enable access")
                }
                .padding(.horizontal, 40)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                if !permissionState.isGranted {
                    Button("Open System Settings") {
                        openAccessibilitySettings()
                    }
                    .controlSize(.large)
                }

                Button(permissionState.isGranted ? "Get Started" : "Continue Without Permission") {
                    onComplete()
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(false)
            }
        }
        .padding(32)
        .frame(width: 480, height: 360)
        .onAppear {
            // Prompt the system dialog on first appearance
            Permissions.checkAccessibility(prompt: true)
        }
    }

    private func instructionRow(step: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(step).")
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(width: 16, alignment: .trailing)
            Text(text)
                .font(.callout)
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Permission Polling

/// Polls AXIsProcessTrusted() every 2s. Uses ObservableObject for macOS 13 compat.
final class PermissionPollState: ObservableObject {

    @Published private(set) var isGranted: Bool = false
    private var cancellable: AnyCancellable?

    init() {
        isGranted = Permissions.isAccessibilityGranted()

        // Poll every 2 seconds while permission is not granted
        cancellable = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let granted = Permissions.isAccessibilityGranted()
                if granted != self.isGranted {
                    self.isGranted = granted
                    if granted {
                        // Stop polling once granted
                        self.cancellable?.cancel()
                        self.cancellable = nil
                    }
                }
            }
    }
}
