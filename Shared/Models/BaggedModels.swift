import Foundation

public enum CaptureInputType: String, Codable, CaseIterable, Sendable {
    case url
    case screenshot
}

public enum CaptureStatus: String, Codable, CaseIterable, Sendable {
    case queued
    case processing
    case needsReview = "needs_review"
    case partiallyResolved = "partially_resolved"
    case completed
    case failed
}

public enum DraftStatus: String, Codable, CaseIterable, Sendable {
    case autoActivated = "auto_activated"
    case needsReview = "needs_review"
    case duplicateCandidate = "duplicate_candidate"
    case rejected
}

public enum PlaceCategory: String, Codable, CaseIterable, Sendable {
    case food
    case coffee
    case bars
    case sights
    case nature
    case shops
    case other
}

public struct GeoCoordinate: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct ResolvedPlace: Codable, Hashable, Sendable {
    public var mapItemIdentifier: String?
    public var coordinate: GeoCoordinate
    public var formattedAddress: String

    public init(mapItemIdentifier: String?, coordinate: GeoCoordinate, formattedAddress: String) {
        self.mapItemIdentifier = mapItemIdentifier
        self.coordinate = coordinate
        self.formattedAddress = formattedAddress
    }
}

public struct CaptureRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var inputType: CaptureInputType
    public var status: CaptureStatus
    public var sourceURL: URL?
    public var sourceDomain: String?
    public var sourceApp: String?
    public var title: String
    public var excerpt: String?
    public var rawText: String?
    public var imageFileName: String?
    public var capturedAtLocation: GeoCoordinate?
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        inputType: CaptureInputType,
        status: CaptureStatus = .queued,
        sourceURL: URL? = nil,
        sourceDomain: String? = nil,
        sourceApp: String? = nil,
        title: String,
        excerpt: String? = nil,
        rawText: String? = nil,
        imageFileName: String? = nil,
        capturedAtLocation: GeoCoordinate? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.inputType = inputType
        self.status = status
        self.sourceURL = sourceURL
        self.sourceDomain = sourceDomain
        self.sourceApp = sourceApp
        self.title = title
        self.excerpt = excerpt
        self.rawText = rawText
        self.imageFileName = imageFileName
        self.capturedAtLocation = capturedAtLocation
        self.errorMessage = errorMessage
    }
}

public struct PlaceDraftRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var captureID: UUID
    public var title: String
    public var category: PlaceCategory
    public var notes: String?
    public var addressLine: String?
    public var city: String?
    public var neighborhood: String?
    public var confidence: Double
    public var status: DraftStatus
    public var sourceExcerpt: String?
    public var resolvedPlace: ResolvedPlace?
    public var duplicateOfPlaceID: UUID?

    public init(
        id: UUID = UUID(),
        captureID: UUID,
        title: String,
        category: PlaceCategory = .other,
        notes: String? = nil,
        addressLine: String? = nil,
        city: String? = nil,
        neighborhood: String? = nil,
        confidence: Double = 0,
        status: DraftStatus = .needsReview,
        sourceExcerpt: String? = nil,
        resolvedPlace: ResolvedPlace? = nil,
        duplicateOfPlaceID: UUID? = nil
    ) {
        self.id = id
        self.captureID = captureID
        self.title = title
        self.category = category
        self.notes = notes
        self.addressLine = addressLine
        self.city = city
        self.neighborhood = neighborhood
        self.confidence = confidence
        self.status = status
        self.sourceExcerpt = sourceExcerpt
        self.resolvedPlace = resolvedPlace
        self.duplicateOfPlaceID = duplicateOfPlaceID
    }
}

public struct ConfirmedPlaceRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var category: PlaceCategory
    public var addressLine: String
    public var city: String?
    public var neighborhood: String?
    public var notes: String?
    public var confidence: Double
    public var coordinate: GeoCoordinate?
    public var sourceDomain: String?
    public var sourceCaptureID: UUID
    public var createdAt: Date
    public var visitedAt: Date?
    public var archivedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        category: PlaceCategory,
        addressLine: String,
        city: String? = nil,
        neighborhood: String? = nil,
        notes: String? = nil,
        confidence: Double,
        coordinate: GeoCoordinate? = nil,
        sourceDomain: String? = nil,
        sourceCaptureID: UUID,
        createdAt: Date = .now,
        visitedAt: Date? = nil,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.addressLine = addressLine
        self.city = city
        self.neighborhood = neighborhood
        self.notes = notes
        self.confidence = confidence
        self.coordinate = coordinate
        self.sourceDomain = sourceDomain
        self.sourceCaptureID = sourceCaptureID
        self.createdAt = createdAt
        self.visitedAt = visitedAt
        self.archivedAt = archivedAt
    }
}

public struct IncomingSharePayload: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var inputType: CaptureInputType
    public var sourceURL: URL?
    public var sourceApp: String?
    public var rawText: String?
    public var imageFileName: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        inputType: CaptureInputType,
        sourceURL: URL? = nil,
        sourceApp: String? = nil,
        rawText: String? = nil,
        imageFileName: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.inputType = inputType
        self.sourceURL = sourceURL
        self.sourceApp = sourceApp
        self.rawText = rawText
        self.imageFileName = imageFileName
    }
}

public struct EnrichmentDraftProposal: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var category: PlaceCategory
    public var notes: String?
    public var addressLine: String?
    public var city: String?
    public var neighborhood: String?
    public var confidence: Double
    public var sourceExcerpt: String?

    public init(
        id: UUID = UUID(),
        title: String,
        category: PlaceCategory = .other,
        notes: String? = nil,
        addressLine: String? = nil,
        city: String? = nil,
        neighborhood: String? = nil,
        confidence: Double,
        sourceExcerpt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.notes = notes
        self.addressLine = addressLine
        self.city = city
        self.neighborhood = neighborhood
        self.confidence = confidence
        self.sourceExcerpt = sourceExcerpt
    }
}

public struct EnrichmentResult: Codable, Hashable, Sendable {
    public var captureID: UUID
    public var status: CaptureStatus
    public var proposals: [EnrichmentDraftProposal]
    public var errorMessage: String?

    public init(captureID: UUID, status: CaptureStatus, proposals: [EnrichmentDraftProposal], errorMessage: String? = nil) {
        self.captureID = captureID
        self.status = status
        self.proposals = proposals
        self.errorMessage = errorMessage
    }
}

public struct WidgetPlaceEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var subtitle: String
    public var category: PlaceCategory
    public var distanceMeters: Double?

    public init(id: UUID, title: String, subtitle: String, category: PlaceCategory, distanceMeters: Double?) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.distanceMeters = distanceMeters
    }
}

public struct BaggedSnapshot: Codable, Sendable {
    public var captures: [CaptureRecord]
    public var drafts: [PlaceDraftRecord]
    public var places: [ConfirmedPlaceRecord]
    public var updatedAt: Date

    public init(captures: [CaptureRecord] = [], drafts: [PlaceDraftRecord] = [], places: [ConfirmedPlaceRecord] = [], updatedAt: Date = .now) {
        self.captures = captures
        self.drafts = drafts
        self.places = places
        self.updatedAt = updatedAt
    }
}

public struct WidgetSnapshot: Codable, Sendable {
    public var generatedAt: Date
    public var lastKnownLocation: GeoCoordinate?
    public var nearbyEntries: [WidgetPlaceEntry]

    public init(generatedAt: Date = .now, lastKnownLocation: GeoCoordinate? = nil, nearbyEntries: [WidgetPlaceEntry] = []) {
        self.generatedAt = generatedAt
        self.lastKnownLocation = lastKnownLocation
        self.nearbyEntries = nearbyEntries
    }
}

