import Foundation

enum DemoStateStoreError: LocalizedError {
    case createDirectoryFailed(URL, Error)
    case loadFailed(URL, Error)
    case saveFailed(URL, Error)
    case resetFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .createDirectoryFailed(let url, let error):
            return "Could not prepare local storage at \(url.path): \(error.localizedDescription)"
        case .loadFailed(let url, let error):
            return "Could not restore local data from \(url.path): \(error.localizedDescription)"
        case .saveFailed(let url, let error):
            return "Could not save local data to \(url.path): \(error.localizedDescription)"
        case .resetFailed(let url, let error):
            return "Could not reset local data at \(url.path): \(error.localizedDescription)"
        }
    }
}

final class DemoStateStore {
    private let fileManager: FileManager
    private let folderURL: URL
    private let stateURL: URL

    init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil,
        filename: String = "demo_state.json"
    ) {
        self.fileManager = fileManager

        let baseURL = baseDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.folderURL = baseURL.appendingPathComponent("AdmitPath", isDirectory: true)
        self.stateURL = self.folderURL.appendingPathComponent(filename)
    }

    func load() throws -> DemoState? {
        try ensureStorageDirectory()
        guard fileManager.fileExists(atPath: stateURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: stateURL)
            return try FormatterFactory.makeJSONDecoder().decode(DemoState.self, from: data)
        } catch {
            throw DemoStateStoreError.loadFailed(stateURL, error)
        }
    }

    func save(_ state: DemoState) throws {
        try ensureStorageDirectory()
        do {
            let data = try FormatterFactory.makeJSONEncoder().encode(state)
            try data.write(to: stateURL, options: [.atomic])
        } catch {
            throw DemoStateStoreError.saveFailed(stateURL, error)
        }
    }

    func reset() throws {
        guard fileManager.fileExists(atPath: stateURL.path) else { return }
        do {
            try fileManager.removeItem(at: stateURL)
        } catch {
            throw DemoStateStoreError.resetFailed(stateURL, error)
        }
    }

    var storageURL: URL { stateURL }

    private func ensureStorageDirectory() throws {
        guard !fileManager.fileExists(atPath: folderURL.path) else { return }
        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw DemoStateStoreError.createDirectoryFailed(folderURL, error)
        }
    }
}
