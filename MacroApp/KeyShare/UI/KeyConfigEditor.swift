import SwiftUI

func formatActionName(_ name: String) -> String {
    name.split(separator: "_")
        .map { $0.capitalized }
        .joined(separator: " ")
}

// MARK: - KeyConfigEditor

/// Sheet for configuring a single key's action and params.
struct KeyConfigEditor: View {
    let keyNumber: Int
    @ObservedObject var configManager: ConfigManager
    let profileName: String
    let onDismiss: () -> Void

    @Environment(\.dismiss) var dismiss

    // Local editing state
    @State private var selectedAction: String = "none"
    @State private var errorMessage: String?
    @State private var showingError = false

    // keyboard_shortcut params
    @State private var useCmd = false
    @State private var useShift = false
    @State private var useCtrl = false
    @State private var useAlt = false
    @State private var shortcutKey = ""

    // app_launch params
    @State private var bundleID = ""
    @State private var appName = ""

    // text_type params
    @State private var typeText = ""
    @State private var typeMethod = "clipboard"

    // desktop_switch params
    @State private var switchDirection = "left"

    // media_control params
    @State private var mediaAction = "play_pause"

    @State private var urlString = ""

    // app_action params
    @State private var appActionBundleID = ""
    @State private var appActionAppName = ""
    @State private var appActionMenuPath: [String] = []
    @State private var appActionShortcutKey = ""
    @State private var appActionShortcutModifiers: [String] = []

    // display name (all action types)
    @State private var displayName = ""

    // macro params
    @State private var macroSteps: [MacroStepModel] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Configure Key \(keyNumber)")
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Form {
                // Action type picker
                Picker("Action Type", selection: $selectedAction) {
                    Text("None").tag("none")
                    ForEach(ActionRegistry.shared.registeredTypes, id: \.self) { type in
                        Text(formatActionName(type)).tag(type)
                    }
                }
                .pickerStyle(.menu)

                TextField("Custom display name (optional)", text: $displayName)
                    .textFieldStyle(.roundedBorder)

                // Action-specific params
                switch selectedAction {
                case "keyboard_shortcut":
                    keyboardShortcutParams
                case "app_launch":
                    appLaunchParams
                case "text_type":
                    textTypeParams
                case "desktop_switch":
                    desktopSwitchParams
                case "media_control":
                    mediaControlParams
                case "open_url":
                    urlOpenParams
                case "app_action":
                    appActionParams
                case "macro":
                    MacroStepEditor(steps: $macroSteps)
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal)

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveBinding()
                    dismiss()
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480, height: 500)
        .onAppear { loadCurrentBinding() }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Action-Specific Parameter Views

    @ViewBuilder
    private var keyboardShortcutParams: some View {
        Section("Modifiers") {
            Toggle("Command", isOn: $useCmd)
            Toggle("Shift", isOn: $useShift)
            Toggle("Control", isOn: $useCtrl)
            Toggle("Option", isOn: $useAlt)
        }
        Section("Key") {
            TextField("Key (e.g. c, v, z, f1, space)", text: $shortcutKey)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var appLaunchParams: some View {
        AppPickerView(bundleID: $bundleID, appName: $appName)
    }

    @ViewBuilder
    private var textTypeParams: some View {
        Section("Text") {
            TextEditor(text: $typeText)
                .frame(minHeight: 60)
                .font(.system(.body, design: .monospaced))
        }
        Section("Method") {
            Picker("Method", selection: $typeMethod) {
                Text("Clipboard (Cmd+V)").tag("clipboard")
                Text("Keystrokes").tag("keystrokes")
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private var desktopSwitchParams: some View {
        Section("Direction") {
            Picker("Direction", selection: $switchDirection) {
                Text("Left").tag("left")
                Text("Right").tag("right")
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var mediaControlParams: some View {
        Section("Media Action") {
            Picker("Action", selection: $mediaAction) {
                Text("Play/Pause").tag("play_pause")
                Text("Next Track").tag("next")
                Text("Previous Track").tag("previous")
                Text("Volume Up").tag("vol_up")
                Text("Volume Down").tag("vol_down")
                Text("Mute").tag("mute")
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private var urlOpenParams: some View {
        Section("URL") {
            TextField("URL", text: $urlString)
                .textFieldStyle(.roundedBorder)

            if !urlString.isEmpty {
                if isValidWebURL(urlString) {
                    Label("Valid URL", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Label("Must start with http:// or https://", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var appActionParams: some View {
        MenuBrowserView(
            bundleID: $appActionBundleID,
            appName: $appActionAppName,
            menuPath: $appActionMenuPath,
            shortcutKey: $appActionShortcutKey,
            shortcutModifiers: $appActionShortcutModifiers
        )
    }

    private func isValidWebURL(_ string: String) -> Bool {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    // MARK: - Load / Save

    private func loadCurrentBinding() {
        guard let profile = configManager.config.profiles[profileName],
              let binding = profile.keys[String(keyNumber)] else { return }

        selectedAction = binding.action
        displayName = binding.displayName ?? ""

        switch binding.action {
        case "keyboard_shortcut":
            let mods = (binding.params["modifiers"]?.anyValue as? [Any])?.compactMap { $0 as? String } ?? []
            useCmd = mods.contains("cmd")
            useShift = mods.contains("shift")
            useCtrl = mods.contains("ctrl")
            useAlt = mods.contains("alt")
            shortcutKey = binding.params["key"]?.stringValue ?? ""
        case "app_launch":
            bundleID = binding.params["bundle_id"]?.stringValue ?? ""
            appName = binding.params["app_name"]?.stringValue ?? ""
        case "text_type":
            typeText = binding.params["text"]?.stringValue ?? ""
            typeMethod = binding.params["method"]?.stringValue ?? "clipboard"
        case "desktop_switch":
            switchDirection = binding.params["direction"]?.stringValue ?? "left"
        case "media_control":
            mediaAction = binding.params["action"]?.stringValue ?? "play_pause"
        case "open_url":
            urlString = binding.params["url"]?.stringValue ?? ""
        case "app_action":
            appActionBundleID = binding.params["bundle_id"]?.stringValue ?? ""
            appActionAppName = binding.params["app_name"]?.stringValue ?? ""
            if let path = binding.params["menu_path"]?.anyValue as? [Any] {
                appActionMenuPath = path.compactMap { $0 as? String }
            }
            if let fallback = binding.params["shortcut_fallback"]?.anyValue as? [String: Any] {
                appActionShortcutKey = fallback["key"] as? String ?? ""
                appActionShortcutModifiers = (fallback["modifiers"] as? [Any])?.compactMap { $0 as? String } ?? []
            }
        case "macro":
            if let stepsArray = binding.params["steps"]?.anyValue as? [[String: Any]] {
                macroSteps = stepsArray.map { MacroStepModel(from: $0) }
            }
        default:
            break
        }
    }

    private func saveBinding() {
        let params: [String: AnyCodable]

        switch selectedAction {
        case "keyboard_shortcut":
            var mods: [String] = []
            if useCmd { mods.append("cmd") }
            if useShift { mods.append("shift") }
            if useCtrl { mods.append("ctrl") }
            if useAlt { mods.append("alt") }
            params = [
                "modifiers": AnyCodable(mods),
                "key": AnyCodable(shortcutKey),
            ]
        case "app_launch":
            var appParams: [String: AnyCodable] = ["bundle_id": AnyCodable(bundleID)]
            if !appName.isEmpty {
                appParams["app_name"] = AnyCodable(appName)
            }
            params = appParams
        case "text_type":
            params = [
                "text": AnyCodable(typeText),
                "method": AnyCodable(typeMethod),
            ]
        case "desktop_switch":
            params = ["direction": AnyCodable(switchDirection)]
        case "media_control":
            params = ["action": AnyCodable(mediaAction)]
        case "open_url":
            params = ["url": AnyCodable(urlString)]
        case "app_action":
            var p: [String: AnyCodable] = [
                "bundle_id": AnyCodable(appActionBundleID),
                "menu_path": AnyCodable(appActionMenuPath),
            ]
            if !appActionAppName.isEmpty {
                p["app_name"] = AnyCodable(appActionAppName)
            }
            if !appActionShortcutKey.isEmpty {
                p["shortcut_fallback"] = AnyCodable([
                    "key": appActionShortcutKey,
                    "modifiers": appActionShortcutModifiers,
                ] as [String: Any])
            }
            params = p
        case "macro":
            params = ["steps": AnyCodable(macroSteps.map { $0.toStepDict() })]
        default:
            params = [:]
        }

        var newBinding = KeyBinding(action: selectedAction, params: params)
        newBinding.displayName = displayName.isEmpty ? nil : displayName
        configManager.config.profiles[profileName]?.keys[String(keyNumber)] = newBinding

        do {
            try configManager.save()
        } catch {
            errorMessage = String(describing: error)
            showingError = true
        }
    }

}
