import Foundation
import WidgetKit

@MainActor
public final class CaptureStore: ObservableObject {
    @Published public private(set) var captures: [CaptureRecord] = []
    @Published public private(set) var drafts: [PlaceDraftRecord] = []
    @Published public private(set) var places: [ConfirmedPlaceRecord] = []
    @Published public private(set) var isRefreshing = false

    private let dataStore: AppDataStore
    private let captureService: CaptureService
    private let locationService: LocationService

    public init(dataStore: AppDataStore, captureService: CaptureService, locationService: LocationService) {
        self.dataStore = dataStore
        self.captureService = captureService
        self.locationService = locationService
    }

    public var pendingReviewCaptures: [CaptureRecord] {
        captures.filter { capture in
            drafts.contains(where: { $0.captureID == capture.id && $0.status == .needsReview })
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    public var duplicateDrafts: [PlaceDraftRecord] {
        drafts.filter { $0.status == .duplicateCandidate }
            .sorted { $0.confidence > $1.confidence }
    }

    public var multiPlaceCaptures: [CaptureRecord] {
        captures.filter { capture in
            drafts.filter { $0.captureID == capture.id && $0.status != .rejected }.count > 1
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    public var failedCaptures: [CaptureRecord] {
        captures
            .filter { $0.status == .failed }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public var recentlySavedPlaces: [ConfirmedPlaceRecord] {
        places
            .filter { $0.archivedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public var archivedPlaces: [ConfirmedPlaceRecord] {
        places
            .filter { $0.archivedAt != nil }
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    public var nearbyPlaces: [ConfirmedPlaceRecord] {
        NearbyQueryService.nearbyPlaces(from: places.filter { $0.visitedAt == nil }, origin: locationService.currentCoordinate)
    }

    public func load() async {
        let snapshot = await dataStore.loadSnapshot()
        captures = snapshot.captures
        drafts = snapshot.drafts
        places = snapshot.places
        await syncWidgetSnapshot()
    }

    public func requestLocationAccess() {
        locationService.requestLocationAccess()
    }

    public func processSharedInbox() async {
        do {
            let payloads = try await dataStore.drainIncomingShares()
            for payload in payloads {
                _ = try await ingest(payload)
            }
        } catch {
            #if DEBUG
            print("Failed to process share inbox: \(error)")
            #endif
        }
    }

    public func ingest(_ payload: IncomingSharePayload) async throws -> CaptureRecord {
        var capture = captureService.buildCapture(from: payload, location: locationService.currentCoordinate)
        captures.insert(capture, at: 0)
        try await persist()

        capture.status = .processing
        replaceCapture(capture)
        try await persist()

        do {
            let proposals = try await captureService.enrichCapture(capture)
            drafts.removeAll { $0.captureID == capture.id }
            drafts.append(contentsOf: markDuplicates(in: proposals))

            if proposals.count == 1, let draft = proposals.first, draft.status == .autoActivated {
                let place = try await captureService.confirm(draft, capture: capture)
                places.append(place)
                drafts.removeAll { $0.id == draft.id }
                capture.status = .completed
            } else {
                capture.status = proposals.count > 1 ? .needsReview : .partiallyResolved
            }

            replaceCapture(capture)
            try await persist()
            return capture
        } catch {
            capture.status = .failed
            capture.errorMessage = error.localizedDescription
            replaceCapture(capture)
            try await persist()
            throw error
        }
    }

    public func drafts(for capture: CaptureRecord) -> [PlaceDraftRecord] {
        drafts
            .filter { $0.captureID == capture.id && $0.status != .rejected }
            .sorted { $0.confidence > $1.confidence }
    }

    public func confirm(draft: PlaceDraftRecord) async throws {
        guard let capture = captures.first(where: { $0.id == draft.captureID }) else { return }
        let confirmed = try await captureService.confirm(draft, capture: capture)
        drafts.removeAll { $0.id == draft.id }
        places.append(confirmed)

        if drafts(for: capture).isEmpty {
            updateCaptureStatus(capture.id, status: .completed)
        }

        try await persist()
    }

    public func reject(draft: PlaceDraftRecord) async throws {
        guard let capture = captures.first(where: { $0.id == draft.captureID }) else { return }
        try await captureService.reject(draft, capture: capture)
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[index].status = .rejected
        }

        if drafts(for: capture).isEmpty {
            updateCaptureStatus(capture.id, status: .completed)
        }

        try await persist()
    }

    public func markVisited(_ place: ConfirmedPlaceRecord) async throws {
        updatePlace(place.id) { $0.visitedAt = .now }
        try await persist()
    }

    public func archive(_ place: ConfirmedPlaceRecord) async throws {
        updatePlace(place.id) { $0.archivedAt = .now }
        try await persist()
    }

    public func resetAll() async throws {
        captures = []
        drafts = []
        places = []
        try await persist()
    }

    private func replaceCapture(_ capture: CaptureRecord) {
        if let index = captures.firstIndex(where: { $0.id == capture.id }) {
            captures[index] = capture
        } else {
            captures.append(capture)
        }
    }

    private func updateCaptureStatus(_ captureID: UUID, status: CaptureStatus) {
        guard let index = captures.firstIndex(where: { $0.id == captureID }) else { return }
        captures[index].status = status
    }

    private func updatePlace(_ placeID: UUID, mutation: (inout ConfirmedPlaceRecord) -> Void) {
        guard let index = places.firstIndex(where: { $0.id == placeID }) else { return }
        mutation(&places[index])
    }

    private func markDuplicates(in proposals: [PlaceDraftRecord]) -> [PlaceDraftRecord] {
        proposals.map { draft in
            var mutableDraft = draft
            let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let existing = places.first(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTitle }) {
                mutableDraft.status = .duplicateCandidate
                mutableDraft.duplicateOfPlaceID = existing.id
            }
            return mutableDraft
        }
    }

    private func persist() async throws {
        let snapshot = BaggedSnapshot(captures: captures, drafts: drafts, places: places, updatedAt: .now)
        try await dataStore.saveSnapshot(snapshot)
        await syncWidgetSnapshot()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func syncWidgetSnapshot() async {
        let widgetSnapshot = WidgetSnapshot(
            generatedAt: .now,
            lastKnownLocation: locationService.currentCoordinate,
            nearbyEntries: NearbyQueryService.widgetEntries(from: places.filter { $0.visitedAt == nil }, origin: locationService.currentCoordinate)
        )

        try? await dataStore.saveWidgetSnapshot(widgetSnapshot)
    }
}
