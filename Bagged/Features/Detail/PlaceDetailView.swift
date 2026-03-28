import SwiftUI
import BaggedShared
import MapKit

struct PlaceDetailView: View {
    @EnvironmentObject private var store: CaptureStore
    let place: ConfirmedPlaceRecord

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Category", value: place.category.rawValue.capitalized)
                LabeledContent("Address", value: place.addressLine)
                if let city = place.city {
                    LabeledContent("City", value: city)
                }
                LabeledContent("Confidence", value: "\(Int(place.confidence * 100))%")
            }

            if let notes = place.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }

            Section("Actions") {
                if let coordinate = place.coordinate,
                   let url = URL(string: "http://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)") {
                    Link("Open in Apple Maps", destination: url)
                }

                Button("Mark Visited") {
                    Task { try? await store.markVisited(place) }
                }

                Button("Archive") {
                    Task { try? await store.archive(place) }
                }
            }
        }
        .navigationTitle(place.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

