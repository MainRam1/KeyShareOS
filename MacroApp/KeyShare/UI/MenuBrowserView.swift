import SwiftUI

struct MenuBrowserView: View {
    @Binding var bundleID: String
    @Binding var appName: String
    @Binding var menuPath: [String]
    @Binding var shortcutKey: String
    @Binding var shortcutModifiers: [String]

    @State private var menuTree: [MenuItemInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastLoadedBundleID: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppPickerView(bundleID: $bundleID, appName: $appName)

            HStack {
                Button("Browse Menus") {
                    loadMenus()
                }
                .disabled(bundleID.isEmpty || isLoading)

                if !menuTree.isEmpty {
                    Button("Refresh") {
                        AppActionAction.clearMenuCache(for: bundleID)
                        loadMenus()
                    }
                    .disabled(bundleID.isEmpty || isLoading)
                }

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if !menuPath.isEmpty {
                HStack {
                    Text("Selected:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(menuPath.joined(separator: " \u{203A} "))
                        .font(.system(.caption, design: .monospaced).bold())
                }
            }

            if !menuTree.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(menuTree) { item in
                            MenuItemRow(item: item, selectedPath: menuPath, onSelect: selectMenuItem)
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 200)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
            }
        }
        .onChange(of: bundleID) { newValue in
            if newValue != lastLoadedBundleID {
                menuTree = []
                errorMessage = nil
            }
        }
    }

    private func loadMenus() {
        guard !bundleID.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        let targetBundleID = bundleID
        DispatchQueue.global(qos: .userInitiated).async {
            let menus = AppActionAction.discoverMenus(for: targetBundleID)
            DispatchQueue.main.async {
                isLoading = false
                lastLoadedBundleID = targetBundleID
                if let menus = menus {
                    menuTree = menus
                    if menus.isEmpty {
                        errorMessage = "No menus found. Make sure the app is running."
                    }
                } else {
                    errorMessage = "Could not read menus. Ensure the app is running and Accessibility is enabled."
                }
            }
        }
    }

    private func selectMenuItem(_ item: MenuItemInfo) {
        menuPath = item.path
        shortcutKey = item.shortcutKey ?? ""
        shortcutModifiers = item.shortcutModifiers ?? []
    }
}

struct MenuItemRow: View {
    let item: MenuItemInfo
    let selectedPath: [String]
    let onSelect: (MenuItemInfo) -> Void

    @State private var isExpanded = false

    private var isSelected: Bool {
        item.path == selectedPath
    }

    var body: some View {
        if item.isSeparator {
            Divider()
                .padding(.horizontal, 8)
        } else if item.hasSubmenu {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(item.children) { child in
                    MenuItemRow(item: child, selectedPath: selectedPath, onSelect: onSelect)
                        .padding(.leading, 8)
                }
            } label: {
                menuLabel
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        } else {
            Button(action: { onSelect(item) }) {
                menuLabel
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
    }

    private var menuLabel: some View {
        HStack {
            Text(item.title)
                .foregroundColor(item.isEnabled ? .primary : .secondary)
            Spacer()
            if let shortcut = item.shortcutDisplay {
                Text(shortcut)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }
}
