import SwiftUI
import BaggedShared

struct CaptureReviewView: View {
    @EnvironmentObject private var store: CaptureStore
    let capture: CaptureRecord

    var body: some View {
        List {
            Section("Source") {
                LabeledContent("Type", value: capture.inputType.rawValue.capitalized)
                LabeledContent("Status", value: capture.status.rawValue)
                if let domain = capture.sourceDomain {
                    LabeledContent("Domain", value: domain)
                }
                if let excerpt = capture.excerpt {
                    Text(excerpt)
                        .font(.subheadline)
                }
            }

            Section("Drafts") {
                ForEach(store.drafts(for: capture)) { draft in
                    DraftReviewCard(capture: capture, draft: draft)
                }
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DraftReviewCard: View {
    @EnvironmentObject private var store: CaptureStore
    let capture: CaptureRecord
    let draft: PlaceDraftRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(draft.title)
                    .font(.headline)
                Text([draft.addressLine, draft.city, draft.neighborhood].compactMap { $0 }.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Confidence \(Int(draft.confidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let notes = draft.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                }
            }

            HStack {
                Button("Reject", role: .destructive) {
                    Task { try? await store.reject(draft: draft) }
                }

                Spacer()

                Button("Save") {
                    Task { try? await store.confirm(draft: draft) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 6)
    }
}

