import Foundation
import BaggedShared

@MainActor
final class AppContainer: ObservableObject {
    let locationService: LocationService
    let store: CaptureStore
    let syncModeDescription: String

    init() {
        let locationService = LocationService()
        self.locationService = locationService

        let syncClient: any SyncClient
        let placeResolver: any PlaceResolutionService
        if let url = BaggedConfiguration.configuredAPIBaseURL() {
            syncClient = RemoteSyncClient(baseURL: url)
            placeResolver = MapKitPlaceResolutionService()
        } else {
            syncClient = PreviewSyncClient()
            placeResolver = PreviewPlaceResolutionService()
        }
        self.syncModeDescription = BaggedConfiguration.syncModeDescription()

        let captureService = CaptureService(
            syncClient: syncClient,
            placeResolver: placeResolver
        )

        self.store = CaptureStore(
            dataStore: AppDataStore(),
            captureService: captureService,
            locationService: locationService
        )
    }
}
