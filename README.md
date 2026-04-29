# GPS Location App

An iOS application built with Swift and SwiftUI that captures and displays the device's GPS location in real time.

## Features

- **Real-time GPS tracking** — Continuously updates latitude, longitude, altitude, speed, and heading
- **Reverse geocoding** — Displays a human-readable address for the current location
- **Accuracy indicators** — Shows horizontal and vertical accuracy in meters
- **Start/Stop control** — Toggle location tracking on and off
- **Permission handling** — Gracefully requests and manages location permissions
- **Clean SwiftUI interface** — Modern card-based layout with status indicators

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Physical iPhone device (GPS is not available in the Simulator)

## Getting Started

1. Clone this repository
2. Open `GPSLocationApp.xcodeproj` in Xcode
3. Select your development team under **Signing & Capabilities**
4. Connect your iPhone and select it as the build target
5. Build and run (Cmd+R)

## Permissions

The app requests **"When In Use"** location permission. On first launch, iOS will prompt the user to allow location access. The permission descriptions are configured in `Info.plist`:

- `NSLocationWhenInUseUsageDescription` — Required for foreground location access
- `NSLocationAlwaysAndWhenInUseUsageDescription` — Optional for background tracking

## Architecture

| File | Description |
|------|-------------|
| `GPSLocationAppApp.swift` | App entry point |
| `ContentView.swift` | Main UI with coordinates, details, address, and controls |
| `LocationManager.swift` | CoreLocation wrapper as an `ObservableObject` |
| `Info.plist` | Location permission descriptions |

## How It Works

1. On launch, the app requests location permission via `CLLocationManager`
2. Once authorized, it starts receiving GPS updates with `kCLLocationAccuracyBest`
3. Each update publishes new coordinates, altitude, speed, and heading via `@Published` properties
4. `CLGeocoder` performs reverse geocoding to convert coordinates to a street address
5. SwiftUI views reactively update whenever the published properties change

## Screenshots

The app displays:
- **Status banner** — Green/red/orange indicator for location permission state
- **Coordinates card** — Latitude and longitude with accuracy
- **Details card** — Altitude, speed (km/h), heading (degrees + cardinal direction), and timestamp
- **Address card** — Reverse-geocoded street address
- **Toggle button** — Start/Stop tracking control

## License

This project is provided as-is for educational purposes.
