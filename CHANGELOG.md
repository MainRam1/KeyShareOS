# Changelog

All notable changes to this project will be documented in this file.

## [5.0.0] - 2026-03-15

### Added
- Website auto-switch: profiles change based on the active tab in Safari or Chrome
- App menu actions: browse and trigger any menu bar item via AXUIElement traversal, with keyboard shortcut fallback
- BrowserURLMonitor: AXObserver-based browser tab detection with debounced domain resolution
- Menu browser UI for selecting menu items in the key config editor
- Website auto-switch rules UI in settings
- NSAppleEventsUsageDescription for browser URL queries

### Changed
- AppSwitchMonitor now supports website match priority over app match
- Profile deletion cleans up website switch rules
- Refactored AppActionAction into separate files for SwiftLint compliance

## [1.0.0] - 2026-02-18

### Added
- 9-key macropad firmware (CircuitPython) with USB serial communication
- macOS companion app (menu bar utility)
- 7 action types: keyboard shortcuts, app launch, text typing, desktop switching, media control, macros, open url
- Profile system with unlimited profiles
- Auto-switch profiles by active application
- Visual 3x3 key grid editor in preferences
- OSD overlay on profile switch
- First-launch onboarding for Accessibility permission
- Device hot-plug detection and sleep/wake recovery
- Config file watching for external edits
- Profile import/export
- GitHub Actions CI/CD pipeline
