import SwiftUI

// MARK: - DelayStepRow

struct DelayStepRow: View {
    @Binding var step: MacroStepModel

    var body: some View {
        HStack {
            Text("Delay")
                .fontWeight(.medium)
            Spacer()
            TextField(
                "ms",
                value: $step.delayMs,
                formatter: NumberFormatter.positiveInteger
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 80)
            Text("ms")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - ActionStepRow

struct ActionStepRow: View {
    @Binding var step: MacroStepModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Action", selection: $step.actionType) {
                ForEach(ActionRegistry.shared.registeredTypes.filter { $0 != "macro" }, id: \.self) { type in
                    Text(formatActionName(type)).tag(type)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            actionParams
        }
    }

    @ViewBuilder
    private var actionParams: some View {
        switch step.actionType {
        case "keyboard_shortcut":
            keyboardShortcutParams
        case "app_launch":
            AppPickerView(bundleID: $step.bundleID, appName: $step.appName)
        case "text_type":
            textTypeParams
        case "desktop_switch":
            desktopSwitchParams
        case "media_control":
            mediaControlParams
        case "open_url":
            TextField("URL", text: $step.urlString)
                .textFieldStyle(.roundedBorder)
        case "app_action":
            MenuBrowserView(
                bundleID: $step.appActionBundleID,
                appName: $step.appActionAppName,
                menuPath: $step.appActionMenuPath,
                shortcutKey: $step.appActionShortcutKey,
                shortcutModifiers: $step.appActionShortcutModifiers
            )
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var keyboardShortcutParams: some View {
        HStack(spacing: 8) {
            Toggle("Cmd", isOn: $step.useCmd)
                .toggleStyle(.checkbox)
            Toggle("Shift", isOn: $step.useShift)
                .toggleStyle(.checkbox)
            Toggle("Ctrl", isOn: $step.useCtrl)
                .toggleStyle(.checkbox)
            Toggle("Opt", isOn: $step.useAlt)
                .toggleStyle(.checkbox)
        }
        TextField("Key (e.g. c, v, space)", text: $step.shortcutKey)
            .textFieldStyle(.roundedBorder)
    }

    @ViewBuilder
    private var textTypeParams: some View {
        TextField("Text to type", text: $step.typeText)
            .textFieldStyle(.roundedBorder)
        Picker("Method", selection: $step.typeMethod) {
            Text("Clipboard (Cmd+V)").tag("clipboard")
            Text("Keystrokes").tag("keystrokes")
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var desktopSwitchParams: some View {
        Picker("Direction", selection: $step.switchDirection) {
            Text("Left").tag("left")
            Text("Right").tag("right")
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var mediaControlParams: some View {
        Picker("Media Action", selection: $step.mediaAction) {
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

// MARK: - NumberFormatter Extension

private extension NumberFormatter {
    static let positiveInteger: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = 60000
        return formatter
    }()
}
