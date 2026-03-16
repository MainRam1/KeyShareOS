import os
import SwiftUI
import UniformTypeIdentifiers

// MARK: - SettingsTabView

/// Settings, import/export, and auto-switch rules.
struct SettingsTabView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var configManager: ConfigManager

    @State private var errorMessage: String?
    @State private var showingError = false

    // Auto-switch editing
    @State private var newBundleID = ""
    @State private var newAppName = ""
    @State private var newSwitchProfile = ""

    @State private var newWebsiteDomain = ""
    @State private var newWebsiteProfile = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.contentPadding) {
                generalSection
                autoSwitchSection
                websiteSwitchSection
                importExportSection
                configSection
            }
            .padding(UIConstants.contentPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: UIConstants.itemSpacing) {
            Text("General")
                .font(UIConstants.sectionHeaderFont)

            Toggle("Launch at Login", isOn: Binding(
                get: { configManager.config.settings.launchAtLogin },
                set: { newValue in
                    configManager.config.settings.launchAtLogin = newValue
                    saveConfig()
                }
            ))
            Text("Note: Launch at login may require the app to be properly signed.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Show OSD on Profile Switch", isOn: Binding(
                get: { configManager.config.settings.showOSD },
                set: { newValue in
                    configManager.config.settings.showOSD = newValue
                    saveConfig()
                }
            ))
        }
    }

    // MARK: - Auto-Switch Rules Section

    private var autoSwitchSection: some View {
        VStack(alignment: .leading, spacing: UIConstants.itemSpacing) {
            Text("Auto-Switch Rules")
                .font(UIConstants.sectionHeaderFont)

            if configManager.config.autoSwitch.isEmpty {
                Text("No auto-switch rules configured.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(configManager.config.autoSwitch.keys.sorted()), id: \.self) { bundleID in
                    HStack {
                        Text(bundleID)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Text(configManager.config.autoSwitch[bundleID] ?? "")
                            .foregroundColor(.secondary)
                        Button(role: .destructive) {
                            configManager.config.autoSwitch.removeValue(forKey: bundleID)
                            saveConfig()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                AppPickerView(bundleID: $newBundleID, appName: $newAppName)

                HStack {
                    Picker("Profile", selection: $newSwitchProfile) {
                        Text("Select...").tag("")
                        ForEach(profileManager.availableProfiles, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)

                    Button("Add Rule") {
                        guard !newBundleID.isEmpty, !newSwitchProfile.isEmpty else { return }
                        configManager.config.autoSwitch[newBundleID] = newSwitchProfile
                        saveConfig()
                        newBundleID = ""
                        newAppName = ""
                        newSwitchProfile = ""
                    }
                    .disabled(newBundleID.isEmpty || newSwitchProfile.isEmpty)
                }
            }
        }
    }

    private var websiteSwitchSection: some View {
        VStack(alignment: .leading, spacing: UIConstants.itemSpacing) {
            Text("Website Auto-Switch")
                .font(UIConstants.sectionHeaderFont)

            Text("Switch profiles based on the active website in Safari or Chrome. Requires Automation permission per browser.")
                .font(.caption)
                .foregroundColor(.secondary)

            let websiteRules = configManager.config.websiteSwitch ?? [:]

            if websiteRules.isEmpty {
                Text("No website rules configured.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(websiteRules.keys.sorted()), id: \.self) { domain in
                    HStack {
                        Text(domain)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Text(websiteRules[domain] ?? "")
                            .foregroundColor(.secondary)
                        Button(role: .destructive) {
                            configManager.config.websiteSwitch?.removeValue(forKey: domain)
                            saveConfig()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Domain (e.g. github.com)", text: $newWebsiteDomain)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)

                HStack {
                    Picker("Profile", selection: $newWebsiteProfile) {
                        Text("Select...").tag("")
                        ForEach(profileManager.availableProfiles, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)

                    Button("Add Rule") {
                        let domain = normalizeDomain(newWebsiteDomain)
                        guard !domain.isEmpty, !newWebsiteProfile.isEmpty else { return }
                        if configManager.config.websiteSwitch == nil {
                            configManager.config.websiteSwitch = [:]
                        }
                        configManager.config.websiteSwitch?[domain] = newWebsiteProfile
                        saveConfig()
                        newWebsiteDomain = ""
                        newWebsiteProfile = ""
                    }
                    .disabled(newWebsiteDomain.trimmingCharacters(in: .whitespaces).isEmpty
                              || newWebsiteProfile.isEmpty)
                }
            }
        }
    }

    private func normalizeDomain(_ input: String) -> String {
        var domain = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if domain.hasPrefix("https://") { domain = String(domain.dropFirst(8)) }
        if domain.hasPrefix("http://") { domain = String(domain.dropFirst(7)) }
        if let slashIndex = domain.firstIndex(of: "/") {
            domain = String(domain[domain.startIndex..<slashIndex])
        }
        if domain.hasPrefix("www.") { domain = String(domain.dropFirst(4)) }
        return domain
    }

    // MARK: - Import / Export Section

    private var importExportSection: some View {
        VStack(alignment: .leading, spacing: UIConstants.itemSpacing) {
            Text("Import / Export")
                .font(UIConstants.sectionHeaderFont)

            HStack {
                Button("Export Selected Profile\u{2026}") {
                    exportActiveProfile()
                }

                Button("Import Profile\u{2026}") {
                    importProfile()
                }
            }
        }
    }

    // MARK: - Configuration Section

    private var configSection: some View {
        VStack(alignment: .leading, spacing: UIConstants.itemSpacing) {
            Text("Configuration")
                .font(UIConstants.sectionHeaderFont)

            HStack {
                Text("Config file:")
                Text(Constants.configFilePath.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Button("Reset to Defaults") {
                do {
                    try configManager.resetToDefault()
                } catch {
                    showError(error)
                }
            }
        }
    }

    // MARK: - Actions

    private func showError(_ error: Error) {
        errorMessage = String(describing: error)
        showingError = true
    }

    private func saveConfig() {
        do {
            try configManager.save()
        } catch {
            showError(error)
        }
    }

    private func exportActiveProfile() {
        let name = profileManager.activeProfile
        do {
            let data = try configManager.exportProfile(name: name)

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "\(name).json"
            panel.canCreateDirectories = true
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    try data.write(to: url, options: .atomic)
                    Log.general.info("Exported profile '\(name)' to \(url.path)")
                } catch {
                    showError(error)
                }
            }
        } catch {
            showError(error)
        }
    }

    private func importProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                let profile = try configManager.decodeImportedProfile(from: data)

                let baseName = url.deletingPathExtension().lastPathComponent
                let name = baseName.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !name.isEmpty else {
                    showError(ProfileError.invalidProfileName(""))
                    return
                }

                configManager.config.profiles[name] = profile
                try configManager.save()
                Log.general.info("Imported profile '\(name)' from \(url.path)")
            } catch {
                showError(error)
            }
        }
    }
}
