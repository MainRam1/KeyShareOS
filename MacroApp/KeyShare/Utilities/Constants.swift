import CoreGraphics
import Foundation
import os

/// Centralized logger. Categories match architectural layers.
enum Log {
    static let general = Logger(subsystem: "com.rampierce.KeyShare", category: "general")
    static let serial = Logger(subsystem: "com.rampierce.KeyShare", category: "serial")
    static let config = Logger(subsystem: "com.rampierce.KeyShare", category: "config")
    static let actions = Logger(subsystem: "com.rampierce.KeyShare", category: "actions")
    static let profiles = Logger(subsystem: "com.rampierce.KeyShare", category: "profiles")
}

enum Constants {

    // MARK: - USB

    static let picoVendorID: Int = 0x239A // Adafruit / CircuitPython

    // MARK: - Serial

    /// USB CDC ignores baud rate but POSIX requires it.
    static let serialBaudRate: speed_t = 115200
    static let serialReadBufferSize: Int = 4096

    // MARK: - Protocol

    static let minimumProtocolVersion: Int = 1
    static let maximumProtocolVersion: Int = 1

    // MARK: - Paths

    static let appSupportDirectoryName: String = "KeyShare"
    static let configFileName: String = "config.json"

    static var configDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent(appSupportDirectoryName)
    }

    static var configFilePath: URL {
        configDirectory.appendingPathComponent(configFileName)
    }

    static let numberOfKeys: Int = 9

    /// WARNING: Number keys are NOT sequential! Verified against macOS SDK.
    enum KeyCodes {
        // Number keys (ANSI layout — NOT sequential!)
        static let n0: CGKeyCode = 0x1D  // 29
        static let n1: CGKeyCode = 0x12  // 18
        static let n2: CGKeyCode = 0x13  // 19
        static let n3: CGKeyCode = 0x14  // 20
        static let n4: CGKeyCode = 0x15  // 21
        static let n5: CGKeyCode = 0x17  // 23 ← NOT 22!
        static let n6: CGKeyCode = 0x16  // 22 ← NOT 23!
        static let n7: CGKeyCode = 0x1A  // 26
        static let n8: CGKeyCode = 0x1C  // 28
        static let n9: CGKeyCode = 0x19  // 25

        // Arrow keys
        static let leftArrow: CGKeyCode = 0x7B   // 123
        static let rightArrow: CGKeyCode = 0x7C  // 124
        static let downArrow: CGKeyCode = 0x7D   // 125
        static let upArrow: CGKeyCode = 0x7E     // 126

        // Common keys
        static let returnKey: CGKeyCode = 0x24    // 36
        static let tab: CGKeyCode = 0x30          // 48
        static let space: CGKeyCode = 0x31        // 49
        static let delete: CGKeyCode = 0x33       // 51 (backspace)
        static let escape: CGKeyCode = 0x35       // 53

        // Letter keys (ANSI layout)
        static let a: CGKeyCode = 0x00
        static let b: CGKeyCode = 0x0B
        static let c: CGKeyCode = 0x08
        static let d: CGKeyCode = 0x02
        static let e: CGKeyCode = 0x0E
        static let f: CGKeyCode = 0x03
        static let g: CGKeyCode = 0x05
        static let h: CGKeyCode = 0x04
        static let i: CGKeyCode = 0x22
        static let j: CGKeyCode = 0x26
        static let k: CGKeyCode = 0x28
        static let l: CGKeyCode = 0x25
        static let m: CGKeyCode = 0x2E
        static let n: CGKeyCode = 0x2D
        static let o: CGKeyCode = 0x1F
        static let p: CGKeyCode = 0x23
        static let q: CGKeyCode = 0x0C
        static let r: CGKeyCode = 0x0F
        static let s: CGKeyCode = 0x01
        static let t: CGKeyCode = 0x11
        static let u: CGKeyCode = 0x20
        static let v: CGKeyCode = 0x09
        static let w: CGKeyCode = 0x0D
        static let x: CGKeyCode = 0x07
        static let y: CGKeyCode = 0x10
        static let z: CGKeyCode = 0x06

        // Function keys
        static let f1: CGKeyCode = 0x7A
        static let f2: CGKeyCode = 0x78
        static let f3: CGKeyCode = 0x63
        static let f4: CGKeyCode = 0x76
        static let f5: CGKeyCode = 0x60
        static let f6: CGKeyCode = 0x61
        static let f7: CGKeyCode = 0x62
        static let f8: CGKeyCode = 0x64
        static let f9: CGKeyCode = 0x65
        static let f10: CGKeyCode = 0x6D
        static let f11: CGKeyCode = 0x67
        static let f12: CGKeyCode = 0x6F

        // Punctuation and symbols
        static let minus: CGKeyCode = 0x1B
        static let equal: CGKeyCode = 0x18
        static let leftBracket: CGKeyCode = 0x21
        static let rightBracket: CGKeyCode = 0x1E
        static let semicolon: CGKeyCode = 0x29
        static let quote: CGKeyCode = 0x27
        static let comma: CGKeyCode = 0x2B
        static let period: CGKeyCode = 0x2F
        static let slash: CGKeyCode = 0x2C
        static let backslash: CGKeyCode = 0x2A
        static let grave: CGKeyCode = 0x32

        private static let nameToCode: [String: CGKeyCode] = {
            var map: [String: CGKeyCode] = [
                "0": n0, "1": n1, "2": n2, "3": n3, "4": n4,
                "5": n5, "6": n6, "7": n7, "8": n8, "9": n9,
                "a": a, "b": b, "c": c, "d": d, "e": e, "f": f,
                "g": g, "h": h, "i": i, "j": j, "k": k, "l": l,
                "m": m, "n": n, "o": o, "p": p, "q": q, "r": r,
                "s": s, "t": t, "u": u, "v": v, "w": w, "x": x,
                "y": y, "z": z,
                "return": returnKey, "tab": tab, "space": space,
                "delete": delete, "escape": escape,
                "left": leftArrow, "right": rightArrow,
                "up": upArrow, "down": downArrow,
                "f1": f1, "f2": f2, "f3": f3, "f4": f4,
                "f5": f5, "f6": f6, "f7": f7, "f8": f8,
                "f9": f9, "f10": f10, "f11": f11, "f12": f12,
                "-": minus, "=": equal,
                "[": leftBracket, "]": rightBracket,
                ";": semicolon, "'": quote,
                ",": comma, ".": period, "/": slash,
                "\\": backslash, "`": grave,
            ]
            return map
        }()

        static func fromName(_ name: String) -> CGKeyCode? {
            return nameToCode[name.lowercased()]
        }

        static func numberKey(_ number: Int) -> CGKeyCode? {
            switch number {
            case 0: return n0
            case 1: return n1
            case 2: return n2
            case 3: return n3
            case 4: return n4
            case 5: return n5
            case 6: return n6
            case 7: return n7
            case 8: return n8
            case 9: return n9
            default: return nil
            }
        }

        static func modifierFlags(from names: [String]) -> CGEventFlags {
            var flags = CGEventFlags()
            for name in names {
                switch name.lowercased() {
                case "cmd", "command": flags.insert(.maskCommand)
                case "shift": flags.insert(.maskShift)
                case "ctrl", "control": flags.insert(.maskControl)
                case "alt", "option": flags.insert(.maskAlternate)
                default: break
                }
            }
            return flags
        }
    }

    enum MediaKeys {
        static let soundUp: UInt32 = 0
        static let soundDown: UInt32 = 1
        static let mute: UInt32 = 7
        static let play: UInt32 = 16
        static let next: UInt32 = 17
        static let previous: UInt32 = 18
    }

    // MARK: - Browsers

    static let safariBundleID = "com.apple.Safari"
    static let chromeBundleID = "com.google.Chrome"
    static let supportedBrowsers: Set<String> = [safariBundleID, chromeBundleID]

    /// Checked before play_pause to prevent rcd from auto-launching Apple Music.
    /// Browsers excluded (always running, false positives).
    static let mediaPlayerBundleIDs: Set<String> = [
        "com.spotify.client",              // Spotify
        "com.apple.Music",                 // Apple Music
        "org.videolan.vlc",                // VLC
        "com.colliderli.iina",             // IINA
        "com.apple.QuickTimePlayerX",      // QuickTime Player
        "com.apple.tv",                    // Apple TV
        "com.apple.podcasts",              // Podcasts
        "com.tidal.desktop",               // TIDAL
        "com.amazon.music",                // Amazon Music
        "tv.plex.desktop",                 // Plex
        "io.mpv",                          // mpv
    ]
}
