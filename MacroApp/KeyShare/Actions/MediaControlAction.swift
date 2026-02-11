import AppKit
import Foundation
import os

/// Controls media playback and volume via NX system-defined key events
/// (same path as physical media keys).
///
/// play_pause has a running-apps guard to prevent rcd from auto-launching
/// Apple Music. next/prev don't need it — rcd silently drops those when
/// no Now Playing session exists. No Accessibility required.
final class MediaControlAction: ActionExecutable {

    static let actionType = "media_control"

    private static let validActions: Set<String> = [
        "play_pause", "next", "prev", "vol_up", "vol_down", "mute"
    ]

    func validate(params: [String: Any]) -> Bool {
        guard let action = params["action"] as? String else { return false }
        return Self.validActions.contains(action)
    }

    func execute(params: [String: Any]) async throws {
        guard let action = params["action"] as? String else {
            throw ActionError.invalidParams(Self.actionType, params)
        }

        switch action {
        case "play_pause":
            guard isMediaPlayerRunning() else {
                Log.actions.info("MediaControl: play_pause skipped — no known media player running")
                return
            }
            postMediaKey(Constants.MediaKeys.play)
        case "next":
            postMediaKey(Constants.MediaKeys.next)
        case "prev":
            postMediaKey(Constants.MediaKeys.previous)
        case "vol_up":
            postMediaKey(Constants.MediaKeys.soundUp)
        case "vol_down":
            postMediaKey(Constants.MediaKeys.soundDown)
        case "mute":
            postMediaKey(Constants.MediaKeys.mute)
        default:
            throw ActionError.invalidParams(Self.actionType, params)
        }
    }

    // MARK: - Running Apps Guard

    /// Browsers excluded — almost always running, causing false positives.
    private func isMediaPlayerRunning() -> Bool {
        let runningBundleIDs = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )
        return !runningBundleIDs.isDisjoint(with: Constants.mediaPlayerBundleIDs)
    }

    // MARK: - NX Media Key Events

    private func postMediaKey(_ keyCode: UInt32) {
        postMediaKeyEvent(keyCode: keyCode, keyDown: true)
        postMediaKeyEvent(keyCode: keyCode, keyDown: false)
    }

    private func postMediaKeyEvent(keyCode: UInt32, keyDown: Bool) {
        let flags: UInt32 = keyDown ? 0x0A00 : 0x0B00
        let data1 = Int((keyCode << 16) | UInt32(flags))

        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )

        event?.cgEvent?.post(tap: .cghidEventTap)
    }
}
