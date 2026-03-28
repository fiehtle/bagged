import XCTest
@testable import BaggedShared

final class NearbyQueryServiceTests: XCTestCase {
    func testNearbyPlacesSortsByDistance() {
        let origin = GeoCoordinate(latitude: 37.7749, longitude: -122.4194)
        let far = ConfirmedPlaceRecord(
            title: "Far",
            category: .food,
            addressLine: "Far",
            confidence: 0.8,
            coordinate: GeoCoordinate(latitude: 37.8044, longitude: -122.2711),
            sourceCaptureID: UUID()
        )
        let near = ConfirmedPlaceRecord(
            title: "Near",
            category: .coffee,
            addressLine: "Near",
            confidence: 0.9,
            coordinate: GeoCoordinate(latitude: 37.7750, longitude: -122.4195),
            sourceCaptureID: UUID()
        )

        let result = NearbyQueryService.nearbyPlaces(from: [far, near], origin: origin)
        XCTAssertEqual(result.first?.title, "Near")
    }
}

final class AppDataStoreTests: XCTestCase {
    func testDataStoreRoundTripsSnapshot() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let store = AppDataStore(
            snapshotURL: directory.appendingPathComponent("snapshot.json"),
            inboxURL: directory.appendingPathComponent("inbox.json"),
            widgetURL: directory.appendingPathComponent("widget.json")
        )

        let snapshot = BaggedSnapshot(
            captures: [CaptureRecord(inputType: .url, title: "Test")],
            drafts: [],
            places: []
        )
        try await store.saveSnapshot(snapshot)

        let loaded = await store.loadSnapshot()
        XCTAssertEqual(loaded.captures.first?.title, "Test")
    }
}

