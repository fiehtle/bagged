import UIKit
import UniformTypeIdentifiers
import BaggedShared

final class ShareViewController: UIViewController {
    private let dataStore = AppDataStore()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task {
            await handleInput()
        }
    }

    private func handleInput() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }

        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    await handleURL(provider)
                    return
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    await handleImage(provider)
                    return
                }
            }
        }

        completeRequest()
    }

    private func handleURL(_ provider: NSItemProvider) async {
        do {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
            guard let url = item as? URL else {
                completeRequest()
                return
            }

            let payload = IncomingSharePayload(
                inputType: .url,
                sourceURL: url
            )
            try await dataStore.appendIncomingShare(payload)
        } catch {
            #if DEBUG
            print("Failed to capture shared URL: \(error)")
            #endif
        }

        completeRequest()
    }

    private func handleImage(_ provider: NSItemProvider) async {
        do {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.image.identifier)
            let fileName = "share-\(UUID().uuidString).jpg"
            let destination = BaggedConfiguration.sharedContainerURL(fileName: fileName)

            if let sourceURL = item as? URL {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try? FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destination)
            } else if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                try data.write(to: destination, options: [.atomic])
            } else {
                completeRequest()
                return
            }

            let payload = IncomingSharePayload(
                inputType: .screenshot,
                imageFileName: fileName
            )
            try await dataStore.appendIncomingShare(payload)
        } catch {
            #if DEBUG
            print("Failed to capture shared image: \(error)")
            #endif
        }

        completeRequest()
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
