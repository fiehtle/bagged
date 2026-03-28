import Foundation

public protocol SyncClient: Sendable {
    func submitCapture(_ capture: CaptureRecord) async throws -> EnrichmentResult
    func confirmDraft(capture: CaptureRecord, draft: PlaceDraftRecord) async throws
    func rejectDraft(capture: CaptureRecord, draft: PlaceDraftRecord) async throws
}

public struct RemoteSyncClient: SyncClient {
    private let session: URLSession
    private let baseURL: URL

    public init(baseURL: URL = BaggedConfiguration.renderWorkerBaseURL ?? URL(string: "https://bagged-worker.onrender.com")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func submitCapture(_ capture: CaptureRecord) async throws -> EnrichmentResult {
        var request = URLRequest(url: baseURL.appending(path: "/v1/captures"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.bagged.encode(capture)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw Self.decodeError(data: data, statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder.bagged.decode(EnrichmentResult.self, from: data)
    }

    public func confirmDraft(capture: CaptureRecord, draft: PlaceDraftRecord) async throws {
        try await updateDraft(path: "/v1/place-drafts/\(draft.id.uuidString)/confirm", capture: capture, draft: draft)
    }

    public func rejectDraft(capture: CaptureRecord, draft: PlaceDraftRecord) async throws {
        try await updateDraft(path: "/v1/place-drafts/\(draft.id.uuidString)/reject", capture: capture, draft: draft)
    }

    private func updateDraft(path: String, capture: CaptureRecord, draft: PlaceDraftRecord) async throws {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.bagged.encode(["captureId": capture.id.uuidString, "draftId": draft.id.uuidString])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw Self.decodeError(data: data, statusCode: httpResponse.statusCode)
        }
    }

    private static func decodeError(data: Data, statusCode: Int) -> Error {
        if let payload = try? JSONDecoder().decode(RemoteSyncErrorPayload.self, from: data),
           let message = payload.error?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            return RemoteSyncError(message: message, statusCode: statusCode, code: payload.code)
        }

        return RemoteSyncError(message: "Worker request failed.", statusCode: statusCode, code: nil)
    }
}

public struct PreviewSyncClient: SyncClient {
    public init() {}

    public func submitCapture(_ capture: CaptureRecord) async throws -> EnrichmentResult {
        let proposals = [EnrichmentDraftProposal(
            title: previewTitle(for: capture),
            category: previewCategory(for: capture),
            notes: capture.rawText,
            city: "San Francisco",
            confidence: capture.inputType == .screenshot ? 0.7 : 0.82,
            sourceExcerpt: capture.sourceURL?.host(percentEncoded: false) ?? capture.title
        )]

        return EnrichmentResult(captureID: capture.id, status: .processing, proposals: proposals)
    }

    public func confirmDraft(capture: CaptureRecord, draft: PlaceDraftRecord) async throws {}

    public func rejectDraft(capture: CaptureRecord, draft: PlaceDraftRecord) async throws {}

    private func previewTitle(for capture: CaptureRecord) -> String {
        if let rawText = capture.rawText?
            .split(separator: "\n")
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return String(rawText)
        }

        if let url = capture.sourceURL {
            let slug = url.deletingPathExtension().lastPathComponent
            if !slug.isEmpty {
                return slug
                    .split(separator: "-")
                    .map { $0.capitalized }
                    .joined(separator: " ")
            }
        }

        return capture.title
    }

    private func previewCategory(for capture: CaptureRecord) -> PlaceCategory {
        let haystack = [capture.sourceURL?.absoluteString, capture.rawText, capture.title]
            .compactMap { $0 }
            .joined(separator: " ")

        if haystack.localizedCaseInsensitiveContains("coffee") || haystack.localizedCaseInsensitiveContains("cafe") {
            return .coffee
        }

        if haystack.localizedCaseInsensitiveContains("bar") || haystack.localizedCaseInsensitiveContains("cocktail") {
            return .bars
        }

        return .food
    }
}

private struct RemoteSyncErrorPayload: Decodable {
    let error: String?
    let code: String?
}

private struct RemoteSyncError: LocalizedError {
    let message: String
    let statusCode: Int
    let code: String?

    var errorDescription: String? {
        if let code {
            return "\(message) (\(code), HTTP \(statusCode))"
        }

        return "\(message) (HTTP \(statusCode))"
    }
}

public extension JSONEncoder {
    static var bagged: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

public extension JSONDecoder {
    static var bagged: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
