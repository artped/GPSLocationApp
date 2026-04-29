import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var altitude: Double = 0.0
    @Published var speed: Double = 0.0
    @Published var course: Double = 0.0
    @Published var horizontalAccuracy: Double = 0.0
    @Published var verticalAccuracy: Double = 0.0
    @Published var timestamp: Date = Date()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var isUpdating: Bool = false
    @Published var address: String = "Searching..."

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    // MARK: - Initialization

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }

    // MARK: - Public Methods

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        locationManager.startUpdatingLocation()
        isUpdating = true
    }

    func stopUpdating() {
        locationManager.stopUpdatingLocation()
        isUpdating = false
    }

    // MARK: - Private Methods

    private func reverseGeocode(location: CLLocation) {
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.address = "Geocoding error: \(error.localizedDescription)"
                }
                return
            }
            if let placemark = placemarks?.first {
                let components = [
                    placemark.name,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.country
                ].compactMap { $0 }
                DispatchQueue.main.async {
                    self.address = components.joined(separator: ", ")
                }
            }
        }
    }

    var cardinalDirection: String {
        guard course >= 0 else { return "N/A" }
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]
        let index = Int((course + 22.5) / 45.0)
        return directions[index]
    }

    var formattedSpeed: String {
        guard speed >= 0 else { return "0.0 km/h" }
        let kmh = speed * 3.6
        return String(format: "%.1f km/h", kmh)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        speed = location.speed
        course = location.course
        horizontalAccuracy = location.horizontalAccuracy
        verticalAccuracy = location.verticalAccuracy
        timestamp = location.timestamp
        locationError = nil

        reverseGeocode(location: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error.localizedDescription
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdating()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable it in Settings."
            stopUpdating()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}
