# Macro

A 9-key macropad built with a Raspberry Pi Pico and a macOS companion app. Assign keyboard shortcuts, launch apps, type text, switch desktops, control media, or chain actions into macros -- all from a compact 3x3 key grid.

## Features

- **6 action types** -- keyboard shortcuts, app launch, text typing, desktop switching, media control, multi-step macros
- **Unlimited profiles** -- organize keys by task or project
- **Auto-switch** -- profiles change automatically based on the active application
- **Visual key editor** -- drag-and-drop 3x3 grid in the preferences window
- **OSD overlay** -- on-screen display when the active profile changes
- **Menu bar utility** -- lives in the menu bar with no Dock icon
- **Hot-plug support** -- detects device connect/disconnect and recovers after sleep
- **Config file watching** -- edits made in a text editor are picked up immediately
- **Profile import/export** -- share profiles as JSON files

## Requirements

| Component | Minimum |
|-----------|---------|
| macOS | 13.0 (Ventura) |
| Microcontroller | Raspberry Pi Pico (RP2040) |
| Switches | 9 x Cherry MX compatible |
| Firmware runtime | CircuitPython 9.x |

## Quick Start

1. **Flash firmware** -- install [CircuitPython 9.x](https://circuitpython.org/board/raspberry_pi_pico/) on the Pico, then copy `firmware/code.py` and `firmware/boot.py` to the `CIRCUITPY` drive.
2. **Download the app** -- grab the latest `.zip` from [GitHub Releases](../../releases), unzip, and move `Macro.app` to `/Applications`.
3. **Launch** -- open the app. It appears in the menu bar.
4. **Grant Accessibility permission** -- the first-launch onboarding will prompt you. Go to **System Settings > Privacy & Security > Accessibility** and enable Macro.
5. **Plug in the macropad** -- the app detects it automatically.

## Building from Source

```bash
# Install xcodegen (once)
brew install xcodegen

# Generate the Xcode project
cd MacroApp
xcodegen generate

# Build
xcodebuild -project MacroApp.xcodeproj -scheme MacroApp -configuration Release build
```

The built `.app` bundle is ad-hoc signed -- no Apple Developer ID required.

## Firmware Setup

1. Hold the BOOTSEL button on the Pico and plug it in via USB.
2. Copy the CircuitPython 9.x `.uf2` file to the `RPI-RP2` drive.
3. After the Pico reboots, copy the firmware files:

```bash
cp firmware/code.py /Volumes/CIRCUITPY/
cp firmware/boot.py /Volumes/CIRCUITPY/
```

The Pico will reboot and begin communicating over USB serial.

## Configuration

The app stores its config at:

```
~/Library/Application Support/Macro/config.json
```

You can edit profiles and key bindings through the preferences window or by editing the JSON file directly. Changes are picked up automatically.

## License

[MIT](LICENSE)
