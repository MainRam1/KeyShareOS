import AppKit
import Foundation

struct InstalledApp: Identifiable {
    let url: URL
    let bundleID: String
    let displayName: String
    let icon: NSImage
    var id: String { bundleID }
}

/// Scans /Applications, /System/Applications, and ~/Applications.
/// Results cached for 60 seconds.
@MainActor
final class ApplicationScanner {

    private static var cachedApps: [InstalledApp] = []
    private static var cacheTimestamp: Date = .distantPast
    private static let cacheTTL: TimeInterval = 60

    static func scan() -> [InstalledApp] {
        if Date().timeIntervalSince(cacheTimestamp) < cacheTTL, !cachedApps.isEmpty {
            return cachedApps
        }

        let apps = performScan()
        cachedApps = apps
        cacheTimestamp = Date()
        return apps
    }

    static func invalidateCache() {
        cachedApps = []
        cacheTimestamp = .distantPast
    }

    private static let applicationDirectories: [String] = {
        var dirs = ["/Applications", "/System/Applications"]
        let home = FileManager.default.homeDirectoryForCurrentUser
        dirs.append(home.appendingPathComponent("Applications").path)
        return dirs
    }()

    private static func performScan() -> [InstalledApp] {
        var seen = Set<String>()
        var apps: [InstalledApp] = []

        for dir in applicationDirectories {
            let dirURL = URL(fileURLWithPath: dir)
            guard let enumerator = FileManager.default.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }

                guard let bundle = Bundle(url: fileURL),
                      let bundleID = bundle.bundleIdentifier,
                      !seen.contains(bundleID) else { continue }

                seen.insert(bundleID)

                let fallbackName = fileURL.deletingPathExtension().lastPathComponent
                let displayName = bundle.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? bundle.infoDictionary?["CFBundleName"] as? String
                    ?? fallbackName

                let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
                icon.size = NSSize(width: 16, height: 16)

                apps.append(InstalledApp(
                    url: fileURL,
                    bundleID: bundleID,
                    displayName: displayName,
                    icon: icon
                ))
            }
        }

        return apps.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}
