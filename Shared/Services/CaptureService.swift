import Foundation

@MainActor
public struct CaptureService {
    private let syncClient: any SyncClient
    private let placeResolver: any PlaceResolutionService

    public init(syncClient: any SyncClient, placeResolver: any PlaceResolutionService) {
        self.syncClient = syncClient
        self.placeResolver = placeResolver
    }

    public func buildCapture(from payload: IncomingSharePayload, location: GeoCoordinate?) -> CaptureRecord {
        let title: String
        switch payload.inputType {
        case .url:
            title = payload.sourceURL?.absoluteString ?? "Untitled URL"
        case .screenshot:
            title = "Screenshot import"
        }

        return CaptureRecord(
            id: payload.id,
            createdAt: payload.createdAt,
            inputType: payload.inputType,
            status: .queued,
            sourceURL: payload.sourceURL,
            sourceDomain: payload.sourceURL?.host(),
            sourceApp: payload.sourceApp,
            title: title,
            rawText: payload.rawText,
            imageFileName: payload.imageFileName,
            capturedAtLocation: location
        )
    }

    public func enrichCapture(_ capture: CaptureRecord) async throws -> [PlaceDraftRecord] {
        let result = try await syncClient.submitCapture(capture)
        var drafts: [PlaceDraftRecord] = []
        let shouldResolveDuringImport = result.proposals.count == 1

        for proposal in result.proposals {
            let resolvedPlace = shouldResolveDuringImport ? await resolveBestEffort(proposal) : nil
            let status: DraftStatus = proposal.confidence >= 0.85 && resolvedPlace != nil ? .autoActivated : .needsReview

            drafts.append(
                PlaceDraftRecord(
                    id: proposal.id,
                    captureID: capture.id,
                    title: proposal.title,
                    category: proposal.category,
                    notes: proposal.notes,
                    addressLine: proposal.addressLine,
                    city: proposal.city,
                    neighborhood: proposal.neighborhood,
                    confidence: proposal.confidence,
                    status: status,
                    sourceExcerpt: proposal.sourceExcerpt,
                    resolvedPlace: resolvedPlace
                )
            )
        }

        return drafts
    }

    public func confirm(_ draft: PlaceDraftRecord, capture: CaptureRecord) async throws -> ConfirmedPlaceRecord {
        try await syncClient.confirmDraft(capture: capture, draft: draft)
        let resolvedPlace: ResolvedPlace?
        if let existingResolvedPlace = draft.resolvedPlace {
            resolvedPlace = existingResolvedPlace
        } else {
            resolvedPlace = await resolveBestEffort(draft)
        }

        return ConfirmedPlaceRecord(
            id: draft.id,
            title: draft.title,
            category: draft.category,
            addressLine: resolvedPlace?.formattedAddress ?? draft.addressLine ?? "Address pending confirmation",
            city: draft.city,
            neighborhood: draft.neighborhood,
            notes: draft.notes,
            confidence: draft.confidence,
            coordinate: resolvedPlace?.coordinate,
            sourceDomain: capture.sourceDomain,
            sourceCaptureID: capture.id
        )
    }

    public func reject(_ draft: PlaceDraftRecord, capture: CaptureRecord) async throws {
        try await syncClient.rejectDraft(capture: capture, draft: draft)
    }

    private func resolveBestEffort(_ proposal: EnrichmentDraftProposal) async -> ResolvedPlace? {
        do {
            return try await placeResolver.resolve(proposal)
        } catch {
            #if DEBUG
            print("Place resolution failed for proposal '\(proposal.title)': \(error)")
            #endif
            return nil
        }
    }

    private func resolveBestEffort(_ draft: PlaceDraftRecord) async -> ResolvedPlace? {
        await resolveBestEffort(
            EnrichmentDraftProposal(
                id: draft.id,
                title: draft.title,
                category: draft.category,
                notes: draft.notes,
                addressLine: draft.addressLine,
                city: draft.city,
                neighborhood: draft.neighborhood,
                confidence: draft.confidence,
                sourceExcerpt: draft.sourceExcerpt
            )
        )
    }
}
