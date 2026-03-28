@preconcurrency import CoreLocation
import Foundation

@MainActor
public final class LocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published public private(set) var authorizationStatus: CLAuthorizationStatus
    @Published public private(set) var currentCoordinate: GeoCoordinate?

    private let manager = CLLocationManager()

    public override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    public func requestLocationAccess() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentCoordinate = GeoCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        #if DEBUG
        print("Location update failed: \(error)")
        #endif
    }
}
