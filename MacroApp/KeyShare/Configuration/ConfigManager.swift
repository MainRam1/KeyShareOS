import Combine
import Foundation
import os

/// Loads, saves, validates, and watches the JSON configuration file.
/// JSONEncoder/JSONDecoder usage is intentionally confined to this file.
final class ConfigManager: ObservableObject {

    @Published var config: MacroConfig

    private let fileManager = FileManager.default
    private let filePath: URL
    private let directoryPath: URL

    private var directoryFileDescriptor: Int32 = -1
    private var directorySource: DispatchSourceFileSystemObject?
    private let fileChangeSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    /// Flag to suppress reload during our own save operations.
    /// Protected by `saveLock` for thread-safe access.
    private var _isSaving = false
    private let saveLock = NSLock()

    private var isSaving: Bool {
        get { saveLock.lock(); defer { saveLock.unlock() }; return _isSaving }
        set { saveLock.lock(); defer { saveLock.unlock() }; _isSaving = newValue }
    }

    convenience init() {
        self.init(
            filePath: Constants.configFilePath,
            directoryPath: Constants.configDirectory
        )
    }

    init(filePath: URL, directoryPath: URL) {
        self.filePath = filePath
        self.directoryPath = directoryPath
        self.config = Self.defaultConfig()

        load()
        startDirectoryMonitor()
        setupDebounce()
    }

    deinit {
        stopDirectoryMonitor()
    }

    func load() {
        do {
            try ensureDirectoryExists()

            guard fileManager.fileExists(atPath: filePath.path) else {
                let defaultConfig = Self.defaultConfig()
                self.config = defaultConfig
                try saveToFile(defaultConfig)
                return
            }

            let data = try readFile()
            let decoded = try decode(data)
            try validate(decoded)
            updateOnMain(decoded)
        } catch {
            // On load failure, keep current config (or default if first load).
            // Log the error for debugging.
            Log.config.error("Load failed: \(error)")
        }
    }

    func save() throws {
        try ensureDirectoryExists()
        try saveToFile(config)
    }

    func updateConfig(_ newConfig: MacroConfig) throws {
        try validate(newConfig)
        try saveToFile(newConfig)
        updateOnMain(newConfig)
    }

    /// Mutate, validate, save, and publish atomically. Rolls back on failure.
    func mutateConfig(_ block: (inout MacroConfig) -> Void) throws {
        var copy = config
        block(&copy)
        try validate(copy)
        try saveToFile(copy)
        updateOnMain(copy)
    }

    func resetToDefault() throws {
        let defaultConfig = Self.defaultConfig()
        try saveToFile(defaultConfig)
        updateOnMain(defaultConfig)
    }

    static func defaultConfig() -> MacroConfig {
        var keys: [String: KeyBinding] = [:]
        for i in 1...Constants.numberOfKeys {
            keys[String(i)] = KeyBinding(action: "none", params: [:])
        }

        return MacroConfig(
            version: 1,
            activeProfile: "general",
            profileOrder: nil,
            profiles: [
                "general": Profile(
                    displayName: "General",
                    keys: keys
                ),
            ],
            autoSwitch: [:],
            settings: AppSettings(launchAtLogin: false, showOSD: true)
        )
    }

    private func readFile() throws -> Data {
        do {
            return try Data(contentsOf: filePath)
        } catch {
            throw ConfigError.fileReadFailed(filePath, error)
        }
    }

    private func decode(_ data: Data) throws -> MacroConfig {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(MacroConfig.self, from: data)
        } catch {
            throw ConfigError.decodingFailed(error)
        }
    }

    private func encode(_ config: MacroConfig) throws -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(config)
        } catch {
            throw ConfigError.encodingFailed(error)
        }
    }

    private func saveToFile(_ config: MacroConfig) throws {
        let data = try encode(config)
        isSaving = true
        defer { isSaving = false }

        do {
            try data.write(to: filePath, options: .atomic)
        } catch {
            throw ConfigError.fileWriteFailed(filePath, error)
        }
    }

    private func ensureDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: directoryPath.path) else { return }
        do {
            try fileManager.createDirectory(
                at: directoryPath,
                withIntermediateDirectories: true
            )
        } catch {
            throw ConfigError.directoryCreationFailed(directoryPath, error)
        }
    }

    private func validate(_ config: MacroConfig) throws {
        guard config.version >= 1 else {
            throw ConfigError.validationFailed(
                "Invalid version: \(config.version). Must be >= 1."
            )
        }
        guard !config.profiles.isEmpty else {
            throw ConfigError.validationFailed("Profiles dictionary must not be empty.")
        }
        guard config.profiles[config.activeProfile] != nil else {
            throw ConfigError.validationFailed(
                "Active profile '\(config.activeProfile)' not found in profiles."
            )
        }
    }

    private func updateOnMain(_ newConfig: MacroConfig) {
        if Thread.isMainThread {
            self.config = newConfig
        } else {
            DispatchQueue.main.async {
                self.config = newConfig
            }
        }
    }

    // Monitor the directory, not the file — atomic writes invalidate file-level DispatchSources.
    private func startDirectoryMonitor() {
        let path = directoryPath.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            Log.config.error("Failed to open directory for monitoring: \(path)")
            return
        }

        directoryFileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.fileChangeSubject.send()
        }

        source.setCancelHandler {
            close(fd)
        }

        directorySource = source
        source.resume()
    }

    private func stopDirectoryMonitor() {
        directorySource?.cancel()
        directorySource = nil
        directoryFileDescriptor = -1
    }

    private func setupDebounce() {
        fileChangeSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.global(qos: .utility))
            .sink { [weak self] in
                guard let self, !self.isSaving else { return }
                self.load()
            }
            .store(in: &cancellables)
    }
}
