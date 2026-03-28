import SwiftUI
import BaggedShared

@main
struct BaggedApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(container.store)
                .environmentObject(container.locationService)
                .task {
                    await container.store.load()
                    container.store.requestLocationAccess()
                    await container.store.processSharedInbox()
                }
        }
    }
}

