import SwiftUI

/// Searchable app picker with icons. Falls back to manual bundle ID entry.
struct AppPickerView: View {
    @Binding var bundleID: String
    @Binding var appName: String

    @State private var searchText = ""
    @State private var useCustomBundleID = false
    @State private var installedApps: [InstalledApp] = []

    var body: some View {
        Group {
            // Show current selection when an app is already chosen
            if !bundleID.isEmpty && !useCustomBundleID {
                currentSelection
            }

            if useCustomBundleID {
                customBundleIDField
            } else {
                appPicker
            }

            Toggle("Use custom Bundle ID", isOn: $useCustomBundleID)
                .toggleStyle(.checkbox)
        }
        .onAppear {
            installedApps = ApplicationScanner.scan()
        }
    }

    @ViewBuilder
    private var currentSelection: some View {
        let matchedApp = installedApps.first(where: { $0.bundleID == bundleID })
        HStack(spacing: 6) {
            if let app = matchedApp {
                Image(nsImage: app.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text(app.displayName)
                    .fontWeight(.medium)
            } else if !appName.isEmpty {
                Text(appName)
                    .fontWeight(.medium)
            } else {
                Text(bundleID)
                    .font(.caption)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var appPicker: some View {
        TextField("Search apps...", text: $searchText)
            .textFieldStyle(.roundedBorder)

        let filtered = filteredApps
        if filtered.isEmpty && !searchText.isEmpty {
            Text("No matching apps found")
                .foregroundColor(.secondary)
                .font(.caption)
        }

        if !installedApps.isEmpty {
            List {
                ForEach(filtered) { app in
                    Button {
                        bundleID = app.bundleID
                        appName = app.displayName
                    } label: {
                        HStack(spacing: 8) {
                            Image(nsImage: app.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.displayName)
                                    .lineLimit(1)
                                Text(app.bundleID)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if app.bundleID == bundleID {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 120, maxHeight: 180)
            .listStyle(.bordered)
        }
    }

    @ViewBuilder
    private var customBundleIDField: some View {
        TextField("Bundle ID (e.g. com.apple.Safari)", text: $bundleID)
            .textFieldStyle(.roundedBorder)
            .onChange(of: bundleID) { _ in
                appName = ""
            }
    }

    private var filteredApps: [InstalledApp] {
        if searchText.isEmpty { return installedApps }
        let query = searchText.lowercased()
        return installedApps.filter {
            $0.displayName.lowercased().contains(query)
                || $0.bundleID.lowercased().contains(query)
        }
    }
}
