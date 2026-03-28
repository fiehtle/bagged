import Contacts
import Foundation
import MapKit

public protocol PlaceResolutionService: Sendable {
    func resolve(_ proposal: EnrichmentDraftProposal) async throws -> ResolvedPlace?
}

public struct MapKitPlaceResolutionService: PlaceResolutionService {
    public init() {}

    public func resolve(_ proposal: EnrichmentDraftProposal) async throws -> ResolvedPlace? {
        let query = [proposal.title, proposal.addressLine, proposal.city]
            .compactMap { $0 }
            .joined(separator: ", ")

        guard !query.isEmpty else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest

        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first,
              item.placemark.location?.coordinate.latitude != nil,
              item.placemark.location?.coordinate.longitude != nil else {
            return nil
        }

        let coordinate = item.placemark.coordinate
        let address = item.placemark.postalAddress.map {
            CNPostalAddressFormatter.string(from: $0, style: .mailingAddress)
                .replacingOccurrences(of: "\n", with: ", ")
        } ?? item.placemark.title ?? query

        return ResolvedPlace(
            mapItemIdentifier: item.name,
            coordinate: GeoCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude),
            formattedAddress: address
        )
    }
}

public struct PreviewPlaceResolutionService: PlaceResolutionService {
    private let anchorCoordinate: GeoCoordinate

    public init(anchorCoordinate: GeoCoordinate = GeoCoordinate(latitude: 37.7749, longitude: -122.4194)) {
        self.anchorCoordinate = anchorCoordinate
    }

    public func resolve(_ proposal: EnrichmentDraftProposal) async throws -> ResolvedPlace? {
        let hashSeed = proposal.title.unicodeScalars.reduce(into: 0) { partialResult, scalar in
            partialResult += Int(scalar.value)
        }

        let latitudeOffset = Double((hashSeed % 120) - 60) / 1_000
        let longitudeOffset = Double(((hashSeed / 7) % 120) - 60) / 1_000
        let coordinate = GeoCoordinate(
            latitude: anchorCoordinate.latitude + latitudeOffset,
            longitude: anchorCoordinate.longitude + longitudeOffset
        )

        let formattedAddress = [proposal.addressLine, proposal.neighborhood, proposal.city]
            .compactMap { $0 }
            .joined(separator: ", ")

        return ResolvedPlace(
            mapItemIdentifier: "preview-\(proposal.title)",
            coordinate: coordinate,
            formattedAddress: formattedAddress.isEmpty ? "\(proposal.title), San Francisco" : formattedAddress
        )
    }
}
