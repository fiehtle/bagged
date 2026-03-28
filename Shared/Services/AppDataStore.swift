import Foundation

public actor AppDataStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let snapshotURL: URL
    private let inboxURL: URL
    private let widgetURL: URL

    public init(
        snapshotURL: URL = BaggedConfiguration.sharedContainerURL(fileName: BaggedConfiguration.sharedStoreFilename),
        inboxURL: URL = BaggedConfiguration.sharedContainerURL(fileName: BaggedConfiguration.sharedInboxFilename),
        widgetURL: URL = BaggedConfiguration.sharedContainerURL(fileName: BaggedConfiguration.widgetSnapshotFilename)
    ) {
        self.snapshotURL = snapshotURL
        self.inboxURL = inboxURL
        self.widgetURL = widgetURL

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func loadSnapshot() -> BaggedSnapshot {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? decoder.decode(BaggedSnapshot.self, from: data) else {
            return BaggedSnapshot()
        }
        return snapshot
    }

    public func saveSnapshot(_ snapshot: BaggedSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: [.atomic])
    }

    public func appendIncomingShare(_ payload: IncomingSharePayload) throws {
        var inbox = loadInbox()
        inbox.append(payload)
        try saveInbox(inbox)
    }

    public func drainIncomingShares() throws -> [IncomingSharePayload] {
        let payloads = loadInbox()
        try saveInbox([])
        return payloads
    }

    public func loadWidgetSnapshot() -> WidgetSnapshot {
        Self.loadWidgetSnapshotSync(from: widgetURL)
    }

    public func saveWidgetSnapshot(_ snapshot: WidgetSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: widgetURL, options: [.atomic])
    }

    public nonisolated static func loadWidgetSnapshotSync(
        from widgetURL: URL = BaggedConfiguration.sharedContainerURL(fileName: BaggedConfiguration.widgetSnapshotFilename)
    ) -> WidgetSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = try? Data(contentsOf: widgetURL),
              let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }

        return snapshot
    }

    private func loadInbox() -> [IncomingSharePayload] {
        guard let data = try? Data(contentsOf: inboxURL),
              let inbox = try? decoder.decode([IncomingSharePayload].self, from: data) else {
            return []
        }
        return inbox
    }

    private func saveInbox(_ inbox: [IncomingSharePayload]) throws {
        let data = try encoder.encode(inbox)
        try data.write(to: inboxURL, options: [.atomic])
    }
}
