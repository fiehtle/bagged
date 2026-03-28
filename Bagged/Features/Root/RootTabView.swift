import SwiftUI
import UIKit
import BaggedShared

private enum RootTab: Hashable {
    case nearby
    case inbox
    case archive
    case lab
}

struct RootTabView: View {
    @State private var selectedTab: RootTab = .nearby
    @State private var isShowingQuickAdd = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                NearbyView()
            }
            .tabItem {
                Label("Nearby", systemImage: "location.viewfinder")
            }
            .tag(RootTab.nearby)

            NavigationStack {
                InboxView()
            }
            .tabItem {
                Label("Inbox", systemImage: "tray.full")
            }
            .tag(RootTab.inbox)

            NavigationStack {
                ArchiveView()
            }
            .tabItem {
                Label("Archive", systemImage: "archivebox")
            }
            .tag(RootTab.archive)

            NavigationStack {
                CaptureLabView()
            }
            .tabItem {
                Label("Test Lab", systemImage: "testtube.2")
            }
            .tag(RootTab.lab)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                isShowingQuickAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.blue, in: Circle())
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 88)
            .accessibilityLabel("Add place")
        }
        .sheet(isPresented: $isShowingQuickAdd) {
            QuickAddSheet { destination in
                selectedTab = destination
            }
        }
    }
}

private struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CaptureStore

    let onImported: (RootTab) -> Void

    @State private var urlText = UIPasteboard.general.string ?? ""
    @State private var rawText = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Add URL") {
                    TextField("https://example.com/list-or-post", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    TextField("Optional notes or pasted excerpt", text: $rawText, axis: .vertical)
                        .lineLimit(3...6)

                    Button("Paste From Clipboard") {
                        if let clipboardURL = UIPasteboard.general.url?.absoluteString {
                            urlText = clipboardURL
                        } else {
                            urlText = UIPasteboard.general.string ?? urlText
                        }
                    }
                }

                if let errorMessage {
                    Section("Error") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await importURL() }
                    } label: {
                        if isImporting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Import")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isImporting)
                }
            }
            .navigationTitle("New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func importURL() async {
        errorMessage = nil
        isImporting = true
        defer { isImporting = false }

        guard let url = BaggedURLParser.normalizedWebURL(from: urlText) else {
            errorMessage = "Paste a full website URL, for example https://example.com/place."
            return
        }

        do {
            let capture = try await store.ingest(
                IncomingSharePayload(
                    inputType: .url,
                    sourceURL: url,
                    sourceApp: "Quick Add",
                    rawText: rawText.nilIfBlank
                )
            )

            onImported(capture.status == .completed ? .nearby : .inbox)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
