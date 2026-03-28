import Foundation

public enum BaggedConfiguration {
    public static let appGroupIdentifier = "group.com.vietle.bagged"
    public static let sharedStoreFilename = "bagged-store.json"
    public static let sharedInboxFilename = "bagged-share-inbox.json"
    public static let widgetSnapshotFilename = "bagged-widget-snapshot.json"
    public static let apiBaseURLInfoKey = "BAGGED_API_BASE_URL"
    public static let bundledConfigFilename = "BaggedConfig"
    public static let renderWorkerBaseURL = URL(string: "https://bagged-worker.onrender.com")

    public static func sharedContainerURL(fileName: String) -> URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return url.appendingPathComponent(fileName)
        }

        let fallbackDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("bagged", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallbackDirectory, withIntermediateDirectories: true)
        return fallbackDirectory.appendingPathComponent(fileName)
    }

    public static func configuredAPIBaseURL(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> URL? {
        if let envValue = processInfo.environment[apiBaseURLInfoKey]?.bagged_trimmedNonEmpty,
           let url = URL(string: envValue) {
            return url
        }

        if let configURL = bundle.url(forResource: bundledConfigFilename, withExtension: "plist"),
           let data = try? Data(contentsOf: configURL),
           let payload = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let bundledValue = payload[apiBaseURLInfoKey] as? String,
           let trimmed = bundledValue.bagged_trimmedNonEmpty,
           let url = URL(string: trimmed) {
            return url
        }

        if let infoValue = bundle.object(forInfoDictionaryKey: apiBaseURLInfoKey) as? String,
           let trimmed = infoValue.bagged_trimmedNonEmpty,
           let url = URL(string: trimmed) {
            return url
        }

        return nil
    }

    public static func syncModeDescription(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> String {
        if let apiBaseURL = configuredAPIBaseURL(bundle: bundle, processInfo: processInfo) {
            return "Live worker: \(apiBaseURL.absoluteString)"
        }

        return "Preview importer"
    }
}

private extension String {
    var bagged_trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
