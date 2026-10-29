import Foundation
import CoreLocation

@MainActor
public final class LocationPermissionService: NSObject, ObservableObject {
    @Published public private(set) var authorizationStatus: CLAuthorizationStatus
    @Published public private(set) var lastRealLocation: CLLocation?
    @Published public private(set) var lastError: String?

    private let manager = CLLocationManager()
    private var deniedForTesting = false

    public override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// Test seam: simulate permission denial without prompting the user.
    public func simulatePermissionDenialForTests() {
        deniedForTesting = true
        authorizationStatus = .denied
        lastError = "Location permission denied."
    }

    public func requestWhenInUseIfNeeded() {
        if deniedForTesting {
            authorizationStatus = .denied
            lastError = "Location permission denied."
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            lastError = "Location permission denied. Enable it in Settings → OpenGPS."
        default:
            break
        }
    }

    public func startUpdating() {
        if deniedForTesting || manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            lastError = "Location permission denied."
            return
        }
        requestWhenInUseIfNeeded()
        manager.startUpdatingLocation()
    }

    public func stopUpdating() {
        manager.stopUpdatingLocation()
    }
}

extension LocationPermissionService: CLLocationManagerDelegate {
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.lastRealLocation = locations.last
            self.lastError = nil
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.lastError = error.localizedDescription
        }
    }
}
