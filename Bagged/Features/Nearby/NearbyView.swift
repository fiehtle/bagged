import SwiftUI
import BaggedShared

struct NearbyView: View {
    @EnvironmentObject private var store: CaptureStore
    @EnvironmentObject private var locationService: LocationService

    var body: some View {
        List {
            if store.nearbyPlaces.isEmpty {
                ContentUnavailableView(
                    "No saved places yet",
                    systemImage: "mappin.slash",
                    description: Text("Share a link or screenshot into bagged to build your nearby list.")
                )
            } else {
                ForEach(store.nearbyPlaces) { place in
                    NavigationLink {
                        PlaceDetailView(place: place)
                    } label: {
                        NearbyRow(place: place, origin: locationService.currentCoordinate)
                    }
                }
            }
        }
        .navigationTitle("Nearby")
    }
}

private struct NearbyRow: View {
    let place: ConfirmedPlaceRecord
    let origin: GeoCoordinate?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(place.title)
                    .font(.headline)
                Spacer()
                if let meters = NearbyQueryService.widgetEntries(from: [place], origin: origin).first?.distanceMeters,
                   meters.isFinite {
                    Text(Measurement(value: meters / 1000, unit: UnitLength.kilometers), format: .measurement(width: .abbreviated, usage: .road))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(place.addressLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text(place.category.rawValue.capitalized)
                if let city = place.city {
                    Text(city)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

