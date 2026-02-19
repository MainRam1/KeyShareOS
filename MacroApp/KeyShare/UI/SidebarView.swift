import SwiftUI

enum SidebarTab: Hashable {
    case keys
    case settings
}

// MARK: - SidebarView

/// Profile list + navigation tabs.
struct SidebarView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var configManager: ConfigManager
    @Binding var selectedTab: SidebarTab

    @State private var showingAddProfile = false
    @State private var newProfileName = ""
    @State private var newDisplayName = ""
    @State private var errorMessage = ""
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 0) {
            profileSection
                .frame(maxHeight: .infinity)

            Divider()
                .padding(.horizontal, UIConstants.sidebarPadding)

            tabSection
                .padding(.vertical, UIConstants.sectionSpacing)
        }
        .frame(width: UIConstants.sidebarWidth)
        .background(UIConstants.sidebarBackground)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Profiles")
                    .font(UIConstants.sectionHeaderFont)
                Spacer()
                Button {
                    newProfileName = ""
                    newDisplayName = ""
                    showingAddProfile = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingAddProfile) {
                    addProfilePopover
                }
            }
            .padding(.horizontal, UIConstants.sidebarPadding)
            .padding(.top, UIConstants.sidebarPadding)
            .padding(.bottom, UIConstants.itemSpacing)

            // Profile list
            ScrollView {
                VStack(spacing: UIConstants.itemSpacing) {
                    ForEach(profileManager.availableProfiles, id: \.self) { name in
                        let displayName = configManager.config.profiles[name]?.displayName ?? name
                        let isActive = name == profileManager.activeProfile

                        SidebarProfileItem(name: displayName, isActive: isActive) {
                            try? profileManager.switchProfile(to: name)
                        }
                        .contextMenu {
                            if !isActive {
                                Button(role: .destructive) {
                                    try? profileManager.deleteProfile(name: name)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, UIConstants.sidebarPadding)
            }
        }
    }

    // MARK: - Tab Section

    private var tabSection: some View {
        VStack(spacing: UIConstants.itemSpacing) {
            SidebarTabItem(
                label: "Keys",
                icon: "keyboard",
                isSelected: selectedTab == .keys
            ) {
                selectedTab = .keys
            }

            SidebarTabItem(
                label: "Settings",
                icon: "gear",
                isSelected: selectedTab == .settings
            ) {
                selectedTab = .settings
            }
        }
        .padding(.horizontal, UIConstants.sidebarPadding)
    }

    // MARK: - Add Profile Popover

    private var addProfilePopover: some View {
        VStack(alignment: .leading, spacing: UIConstants.itemSpacing) {
            Text("New Profile")
                .font(UIConstants.sectionHeaderFont)

            TextField("Profile name", text: $newProfileName)
                .textFieldStyle(.roundedBorder)

            TextField("Display name (optional)", text: $newDisplayName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") {
                    showingAddProfile = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    addProfile()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 260)
    }

    // MARK: - Actions

    private func addProfile() {
        let display = newDisplayName.isEmpty ? newProfileName : newDisplayName
        do {
            try profileManager.addProfile(name: newProfileName, displayName: display)
            showingAddProfile = false
        } catch {
            errorMessage = String(describing: error)
            showingError = true
        }
    }
}

// MARK: - SidebarProfileItem

struct SidebarProfileItem: View {
    let name: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .font(UIConstants.sidebarItemFont)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, UIConstants.sidebarPadding)
            .frame(maxWidth: .infinity, minHeight: UIConstants.sidebarItemHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.sidebarItemCornerRadius, style: .continuous)
                    .fill(itemBackground)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var itemBackground: Color {
        if isActive {
            return UIConstants.sidebarActiveBackground
        } else if isHovered {
            return UIConstants.sidebarHoverBackground
        } else {
            return Color.clear
        }
    }
}

// MARK: - SidebarTabItem

struct SidebarTabItem: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: UIConstants.itemSpacing) {
                Image(systemName: icon)
                Text(label)
                    .font(UIConstants.sidebarTabFont)
                Spacer()
            }
            .padding(.horizontal, UIConstants.sidebarPadding)
            .frame(maxWidth: .infinity, minHeight: UIConstants.sidebarItemHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.sidebarItemCornerRadius, style: .continuous)
                    .fill(itemBackground)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var itemBackground: Color {
        if isSelected {
            return UIConstants.sidebarActiveBackground
        } else if isHovered {
            return UIConstants.sidebarHoverBackground
        } else {
            return Color.clear
        }
    }
}
