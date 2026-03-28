import SwiftUI
import BaggedShared

struct InboxView: View {
    @EnvironmentObject private var store: CaptureStore

    var body: some View {
        List {
            if !store.failedCaptures.isEmpty {
                Section("Failed Imports") {
                    ForEach(store.failedCaptures) { capture in
                        NavigationLink(value: capture) {
                            CaptureRow(capture: capture, subtitle: capture.errorMessage ?? "Import failed")
                        }
                    }
                }
            }

            if !store.pendingReviewCaptures.isEmpty {
                Section("Pending Review") {
                    ForEach(store.pendingReviewCaptures) { capture in
                        NavigationLink(value: capture) {
                            CaptureRow(capture: capture, subtitle: "Needs review")
                        }
                    }
                }
            }

            if !store.multiPlaceCaptures.isEmpty {
                Section("Multi-place Imports") {
                    ForEach(store.multiPlaceCaptures) { capture in
                        NavigationLink(value: capture) {
                            CaptureRow(capture: capture, subtitle: "\(store.drafts(for: capture).count) drafts")
                        }
                    }
                }
            }

            if !store.duplicateDrafts.isEmpty {
                Section("Possible Duplicates") {
                    ForEach(store.duplicateDrafts) { draft in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(draft.title)
                                .font(.headline)
                            Text(draft.addressLine ?? draft.city ?? "Existing place may already be saved")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Confidence \(Int(draft.confidence * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Recently Saved") {
                ForEach(store.recentlySavedPlaces.prefix(10)) { place in
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
        .navigationTitle("Inbox")
        .navigationDestination(for: CaptureRecord.self) { capture in
            CaptureReviewView(capture: capture)
        }
    }
}

private struct CaptureRow: View {
    let capture: CaptureRecord
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(capture.title)
                .font(.headline)
                .lineLimit(2)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let url = capture.sourceURL {
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
