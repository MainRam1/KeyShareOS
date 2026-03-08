import SwiftUI
import UniformTypeIdentifiers

enum SidebarTab: Hashable {
    case keys
    case settings
}

struct SidebarView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var configManager: ConfigManager
    @Binding var selectedTab: SidebarTab

    @State private var showingAddProfile = false
    @State private var newProfileName = ""
    @State private var newDisplayName = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var draggedProfile: String?
    @State private var hoveredProfile: String?
    @State private var renamingProfile: String?

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

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            ScrollView {
                VStack(spacing: UIConstants.itemSpacing) {
                    ForEach(profileManager.availableProfiles, id: \.self) { name in
                        let displayName = configManager.config.profiles[name]?.displayName ?? name
                        let isActive = name == profileManager.activeProfile

                        SidebarProfileItem(
                            name: displayName,
                            isActive: isActive,
                            isDropTarget: hoveredProfile == name,
                            isEditing: renamingProfile == name,
                            action: {
                                try? profileManager.switchProfile(to: name)
                            },
                            onRename: { newName in
                                try? profileManager.renameProfile(name, displayName: newName)
                                renamingProfile = nil
                            },
                            onStartEditing: {
                                renamingProfile = name
                            },
                            onCancelEditing: {
                                renamingProfile = nil
                            }
                        )
                        .contextMenu {
                            Button {
                                renamingProfile = name
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            if !isActive {
                                Button(role: .destructive) {
                                    try? profileManager.deleteProfile(name: name)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDrag {
                            draggedProfile = name
                            return NSItemProvider(object: name as NSString)
                        }
                        .onDrop(
                            of: [.plainText],
                            delegate: ProfileSwapDropDelegate(
                                targetProfile: name,
                                draggedProfile: $draggedProfile,
                                hoveredProfile: $hoveredProfile,
                                onReorder: { source, target in
                                    try? profileManager.moveProfile(from: source, to: target)
                                }
                            )
                        )
                        .opacity(draggedProfile == name ? 0.4 : 1.0)
                    }
                }
                .padding(.horizontal, UIConstants.sidebarPadding)
            }
        }
    }

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

struct SidebarProfileItem: View {
    let name: String
    let isActive: Bool
    let isDropTarget: Bool
    let isEditing: Bool
    let action: () -> Void
    var onRename: ((String) -> Void)?
    var onStartEditing: (() -> Void)?
    var onCancelEditing: (() -> Void)?

    @State private var isHovered = false
    @State private var editText = ""

    var body: some View {
        HStack {
            if isEditing {
                TextField("", text: $editText, onCommit: commitRename)
                    .textFieldStyle(.plain)
                    .font(UIConstants.sidebarItemFont)
                    .onExitCommand { cancelRename() }
                    .onAppear { editText = name }
            } else {
                Button(action: action) {
                    HStack {
                        Text(name)
                            .font(UIConstants.sidebarItemFont)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, UIConstants.sidebarPadding)
        .frame(maxWidth: .infinity, minHeight: UIConstants.sidebarItemHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: UIConstants.sidebarItemCornerRadius, style: .continuous)
                .fill(itemBackground)
        )
        .scaleEffect(isDropTarget ? 1.05 : 1.0)
        .shadow(
            color: isDropTarget ? .accentColor.opacity(0.4) : .clear,
            radius: isDropTarget ? 8 : 0
        )
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { onStartEditing?() }
    }

    private func commitRename() {
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != name {
            onRename?(trimmed)
        } else {
            onCancelEditing?()
        }
    }

    private func cancelRename() {
        onCancelEditing?()
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

struct ProfileSwapDropDelegate: DropDelegate {
    let targetProfile: String
    @Binding var draggedProfile: String?
    @Binding var hoveredProfile: String?
    let onReorder: (String, String) -> Void

    func dropEntered(info: DropInfo) {
        hoveredProfile = targetProfile
    }

    func dropExited(info: DropInfo) {
        if hoveredProfile == targetProfile {
            hoveredProfile = nil
        }
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedProfile != nil && draggedProfile != targetProfile
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let source = draggedProfile, source != targetProfile else {
            hoveredProfile = nil
            draggedProfile = nil
            return false
        }
        onReorder(source, targetProfile)
        hoveredProfile = nil
        draggedProfile = nil
        return true
    }
}

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
