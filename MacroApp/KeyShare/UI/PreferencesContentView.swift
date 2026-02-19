import SwiftUI

/// Root view for the preferences window. Sidebar + main content area.
struct PreferencesContentView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var configManager: ConfigManager

    @State private var selectedTab: SidebarTab = .keys

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                profileManager: profileManager,
                configManager: configManager,
                selectedTab: $selectedTab
            )

            // Main content area
            Group {
                switch selectedTab {
                case .keys:
                    KeyGridView(profileManager: profileManager, configManager: configManager)
                case .settings:
                    SettingsTabView(
                        profileManager: profileManager,
                        configManager: configManager
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            minWidth: UIConstants.windowMinWidth,
            minHeight: UIConstants.windowMinHeight
        )
    }
}
