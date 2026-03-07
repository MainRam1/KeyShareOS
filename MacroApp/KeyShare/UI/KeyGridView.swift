import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 3x3 grid of macropad keys. Tap to edit, drag to swap.
struct KeyGridView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var configManager: ConfigManager

    @State private var selectedKey: Int?
    @State private var draggedKey: Int?
    @State private var hoveredKey: Int?
    @State private var installedApps: [InstalledApp] = []

    var body: some View {
        GeometryReader { geometry in
            let keySize = UIConstants.computedKeySize(for: geometry.size.width)
            let columns = Array(
                repeating: GridItem(.fixed(keySize), spacing: UIConstants.gridSpacing),
                count: 3
            )

            LazyVGrid(columns: columns, spacing: UIConstants.gridSpacing) {
                ForEach(1...Constants.numberOfKeys, id: \.self) { keyNumber in
                    KeyButton(
                        keyNumber: keyNumber,
                        binding: activeBinding(for: keyNumber),
                        keySize: keySize,
                        isDropTarget: hoveredKey == keyNumber,
                        installedApps: installedApps
                    )
                    .onTapGesture { selectedKey = keyNumber }
                    .onDrag {
                        draggedKey = keyNumber
                        return NSItemProvider(object: String(keyNumber) as NSString)
                    } preview: {
                        KeyButton(
                            keyNumber: keyNumber,
                            binding: activeBinding(for: keyNumber),
                            keySize: keySize,
                            isDropTarget: false,
                            installedApps: installedApps
                        )
                        .frame(width: keySize, height: keySize)
                    }
                    .onDrop(
                        of: [.plainText],
                        delegate: KeySwapDropDelegate(
                            targetKey: keyNumber,
                            configManager: configManager,
                            profileName: profileManager.activeProfile,
                            draggedKey: $draggedKey,
                            hoveredKey: $hoveredKey
                        )
                    )
                    .opacity(draggedKey == keyNumber ? 0.4 : 1.0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .onAppear { installedApps = ApplicationScanner.scan() }
        .sheet(item: Binding(
            get: { selectedKey.map { SelectedKeyID(key: $0) } },
            set: { selectedKey = $0?.key }
        )) { selection in
            KeyConfigEditor(
                keyNumber: selection.key,
                configManager: configManager,
                profileName: profileManager.activeProfile,
                onDismiss: { selectedKey = nil }
            )
        }
    }

    private func activeBinding(for keyNumber: Int) -> KeyBinding? {
        let profile = configManager.config.profiles[profileManager.activeProfile]
        return profile?.keys[String(keyNumber)]
    }
}

// MARK: - SelectedKeyID

/// Wrapper so `.sheet(item:)` works with a plain Int.
struct SelectedKeyID: Identifiable {
    let key: Int
    var id: Int { key }
}

// MARK: - KeyButton

struct KeyButton: View {
    let keyNumber: Int
    let binding: KeyBinding?
    let keySize: CGFloat
    let isDropTarget: Bool
    let installedApps: [InstalledApp]

    private var isAppLaunch: Bool {
        binding?.action == "app_launch"
    }

    private var appIcon: NSImage? {
        guard isAppLaunch,
              let bundleID = binding?.params["bundle_id"]?.stringValue else {
            return nil
        }
        return installedApps.first(where: { $0.bundleID == bundleID })?.icon
    }

    private var appDisplayName: String {
        if let name = binding?.params["app_name"]?.stringValue, !name.isEmpty {
            return name
        }
        if let bundleID = binding?.params["bundle_id"]?.stringValue {
            let parts = bundleID.split(separator: ".")
            return String(parts.last ?? "App")
        }
        return "App"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(
                cornerRadius: UIConstants.scaled(UIConstants.keyCornerRadius, for: keySize),
                style: .continuous
            )
            .fill(UIConstants.keyBackground)

            // Key number badge
            Text("\(keyNumber)")
                .font(UIConstants.keyNumberFont)
                .foregroundColor(.secondary)
                .padding(6)

            // Center content
            if isAppLaunch {
                appLaunchContent
            } else {
                actionTextContent
            }
        }
        .frame(width: keySize, height: keySize)
        .scaleEffect(isDropTarget ? 1.05 : 1.0)
        .shadow(
            color: isDropTarget ? .accentColor.opacity(0.4) : .clear,
            radius: isDropTarget ? 8 : 0
        )
        .overlay(
            isDropTarget
                ? RoundedRectangle(
                    cornerRadius: UIConstants.scaled(UIConstants.keyCornerRadius, for: keySize),
                    style: .continuous
                  ).stroke(Color.accentColor, lineWidth: 2)
                : nil
        )
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
    }

    private var appLaunchContent: some View {
        VStack(spacing: 2) {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: UIConstants.scaled(UIConstants.keyIconSize, for: keySize),
                        height: UIConstants.scaled(UIConstants.keyIconSize, for: keySize)
                    )
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
            Text(appDisplayName)
                .font(UIConstants.keyAppNameFont)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionTextContent: some View {
        Text(actionSummary)
            .font(UIConstants.keyActionFont)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionSummary: String {
        if let name = binding?.displayName, !name.isEmpty {
            return name
        }

        guard let binding = binding, binding.action != "none" else {
            return "Not configured"
        }

        switch binding.action {
        case "keyboard_shortcut":
            let mods = (binding.params["modifiers"]?.anyValue as? [Any])?.compactMap { $0 as? String } ?? []
            let key = binding.params["key"]?.stringValue ?? "?"
            return (mods + [key]).joined(separator: "+")
        case "app_launch":
            return appDisplayName
        case "text_type":
            let text = binding.params["text"]?.stringValue ?? ""
            let preview = String(text.prefix(20))
            return "Type: \(preview)\(text.count > 20 ? "..." : "")"
        case "desktop_switch":
            let dir = binding.params["direction"]?.stringValue ?? "?"
            return "Desktop \(dir)"
        case "media_control":
            let act = binding.params["action"]?.stringValue ?? "?"
            return act.replacingOccurrences(of: "_", with: " ").capitalized
        case "open_url":
            let url = binding.params["url"]?.stringValue ?? ""
            let display = url.count > 25 ? String(url.prefix(25)) + "..." : url
            return display.isEmpty ? "Open URL" : display
        case "macro":
            return "Macro"
        default:
            return binding.action
        }
    }
}

// MARK: - KeySwapDropDelegate

struct KeySwapDropDelegate: DropDelegate {
    let targetKey: Int
    let configManager: ConfigManager
    let profileName: String
    @Binding var draggedKey: Int?
    @Binding var hoveredKey: Int?

    func dropEntered(info: DropInfo) {
        hoveredKey = targetKey
    }

    func dropExited(info: DropInfo) {
        if hoveredKey == targetKey {
            hoveredKey = nil
        }
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedKey != nil && draggedKey != targetKey
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let sourceKey = draggedKey, sourceKey != targetKey else {
            hoveredKey = nil
            draggedKey = nil
            return false
        }
        configManager.config.swapKeys(sourceKey, targetKey, in: profileName)
        try? configManager.save()
        hoveredKey = nil
        draggedKey = nil
        return true
    }
}
