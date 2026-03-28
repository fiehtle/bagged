import SwiftUI
import BaggedShared

struct CaptureLabView: View {
    @EnvironmentObject private var store: CaptureStore

    @State private var inputType: CaptureInputType = .url
    @State private var sourceURLText = "https://www.theinfatuation.com/san-francisco/guides/best-restaurants-in-san-francisco"
    @State private var sourceAppText = ""
    @State private var rawText = ""
    @State private var isSubmitting = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        Form {
            Section("Runtime") {
                LabeledContent("Sync", value: BaggedConfiguration.syncModeDescription())
                LabeledContent("Captures", value: "\(store.captures.count)")
                LabeledContent("Drafts", value: "\(store.drafts.count)")
                LabeledContent("Places", value: "\(store.places.count)")

                Text("Use preview mode for deterministic local testing, or set `BAGGED_API_BASE_URL` in `Bagged/Resources/BaggedConfig.plist` to hit a live worker.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Quick Imports") {
                Button("Infatuation List") {
                    importPreset(
                        url: "https://www.theinfatuation.com/san-francisco/guides/best-restaurants-in-san-francisco",
                        sourceApp: "Safari",
                        rawText: "Best restaurants in San Francisco"
                    )
                }

                Button("Instagram Reel") {
                    importPreset(
                        url: "https://www.instagram.com/reel/DMOCK1234/",
                        sourceApp: "Instagram",
                        rawText: "Cute SF brunch spot with matcha and pastries"
                    )
                }

                Button("TikTok") {
                    importPreset(
                        url: "https://www.tiktok.com/@creator/video/1234567890",
                        sourceApp: "TikTok",
                        rawText: "late night ramen in the mission"
                    )
                }

                Button("Screenshot OCR") {
                    importScreenshotPreset(
                        sourceApp: "Photos",
                        rawText: """
                        Pinhole Coffee
                        231 Cortland Ave
                        San Francisco, CA
                        cappuccino, seasonal toast
                        """
                    )
                }
            }

            Section("Custom Capture") {
                Picker("Type", selection: $inputType) {
                    ForEach(CaptureInputType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if inputType == .url {
                    TextField("https://example.com/article", text: $sourceURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                TextField("Source app (optional)", text: $sourceAppText)
                    .textInputAutocapitalization(.words)

                TextField(
                    inputType == .url ? "Notes or page text (optional)" : "Paste OCR text",
                    text: $rawText,
                    axis: .vertical
                )
                .lineLimit(4...8)

                Button {
                    Task { await submitCustomCapture() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Run Import")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSubmitting)
            }

            if let statusMessage {
                Section(statusIsError ? "Error" : "Status") {
                    Text(statusMessage)
                        .foregroundStyle(statusIsError ? .red : .secondary)
                }
            }

            Section("Maintenance") {
                Button("Clear Local Test Data", role: .destructive) {
                    Task { await clearLocalData() }
                }
            }
        }
        .navigationTitle("Test Lab")
    }

    private func importPreset(url: String, sourceApp: String, rawText: String?) {
        sourceURLText = url
        sourceAppText = sourceApp
        self.rawText = rawText ?? ""
        inputType = .url
        Task { await submitCustomCapture() }
    }

    private func importScreenshotPreset(sourceApp: String, rawText: String) {
        inputType = .screenshot
        sourceAppText = sourceApp
        self.rawText = rawText
        Task { await submitCustomCapture() }
    }

    private func submitCustomCapture() async {
        statusMessage = nil
        statusIsError = false
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let payload: IncomingSharePayload
            switch inputType {
            case .url:
                guard let url = URL(string: sourceURLText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    throw LabError.invalidURL
                }
                payload = IncomingSharePayload(
                    inputType: .url,
                    sourceURL: url,
                    sourceApp: sourceAppText.nilIfBlank,
                    rawText: rawText.nilIfBlank
                )
            case .screenshot:
                payload = IncomingSharePayload(
                    inputType: .screenshot,
                    sourceApp: sourceAppText.nilIfBlank,
                    rawText: rawText.nilIfBlank
                )
            }

            let capture = try await store.ingest(payload)
            statusMessage = capture.status == .completed ? "Import completed and saved to Nearby." : "Import completed. Check Inbox for review."
        } catch {
            statusIsError = true
            statusMessage = error.localizedDescription
        }
    }

    private func clearLocalData() async {
        statusMessage = nil
        statusIsError = false

        do {
            try await store.resetAll()
            statusMessage = "Local captures, drafts, and places cleared."
        } catch {
            statusIsError = true
            statusMessage = error.localizedDescription
        }
    }
}

private enum LabError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a valid URL before running a URL import."
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
