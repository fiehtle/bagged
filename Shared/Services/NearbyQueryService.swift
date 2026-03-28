import CoreLocation
import Foundation

public enum NearbyQueryService {
    public static func nearbyPlaces(
        from places: [ConfirmedPlaceRecord],
        origin: GeoCoordinate?
    ) -> [ConfirmedPlaceRecord] {
        guard let origin else {
            return places
                .filter { $0.archivedAt == nil }
                .sorted { $0.createdAt > $1.createdAt }
        }

        let source = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        return places
            .filter { $0.archivedAt == nil }
            .sorted { lhs, rhs in
                distance(from: lhs.coordinate, to: source) < distance(from: rhs.coordinate, to: source)
            }
    }

    public static func widgetEntries(
        from places: [ConfirmedPlaceRecord],
        origin: GeoCoordinate?
    ) -> [WidgetPlaceEntry] {
        let source = origin.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        return nearbyPlaces(from: places, origin: origin)
            .prefix(3)
            .map { place in
                WidgetPlaceEntry(
                    id: place.id,
                    title: place.title,
                    subtitle: [place.neighborhood, place.city, place.addressLine]
                        .compactMap { $0 }
                        .first ?? place.addressLine,
                    category: place.category,
                    distanceMeters: distance(from: place.coordinate, to: source)
                )
            }
    }

    public static func distance(from coordinate: GeoCoordinate?, to origin: CLLocation?) -> Double {
        guard let coordinate, let origin else { return .greatestFiniteMagnitude }
        let destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return origin.distance(from: destination)
    }

    private static func distance(from coordinate: GeoCoordinate?, to origin: CLLocation) -> Double {
        guard let coordinate else { return .greatestFiniteMagnitude }
        let destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return origin.distance(from: destination)
    }
}

