import SwiftUI
import BaggedShared

struct ArchiveView: View {
    @EnvironmentObject private var store: CaptureStore

    var body: some View {
        List {
            if store.archivedPlaces.isEmpty {
                ContentUnavailableView(
                    "No archived places",
                    systemImage: "archivebox",
                    description: Text("Archived or visited places will show up here.")
                )
            } else {
                ForEach(store.archivedPlaces) { place in
                    NavigationLink {
                        PlaceDetailView(place: place)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.title)
                                .font(.headline)
                            Text(place.addressLine)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Archive")
    }
}
