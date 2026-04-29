import SwiftUI
import CoreLocation

struct ContentView: View {

    @StateObject private var locationManager = LocationManager()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    statusBanner
                    coordinatesCard
                    detailsCard
                    addressCard
                    toggleButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("GPS Location")
        }
        .onAppear {
            locationManager.requestPermission()
        }
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.title2)
            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if locationManager.isUpdating {
                ProgressView()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(statusColor.opacity(0.1))
        )
    }

    private var statusIcon: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "location.fill"
        case .denied, .restricted:
            return "location.slash.fill"
        default:
            return "location.circle"
        }
    }

    private var statusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        case .denied, .restricted:
            return .red
        default:
            return .orange
        }
    }

    private var statusText: String {
        if let error = locationManager.locationError {
            return error
        }
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse:
            return "Location access: While In Use"
        case .authorizedAlways:
            return "Location access: Always"
        case .denied:
            return "Location access denied"
        case .restricted:
            return "Location access restricted"
        case .notDetermined:
            return "Requesting location permission..."
        @unknown default:
            return "Unknown status"
        }
    }

    // MARK: - Coordinates Card

    private var coordinatesCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.blue)
                Text("Coordinates")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 20) {
                coordinateItem(
                    label: "Latitude",
                    value: String(format: "%.6f°", locationManager.latitude),
                    icon: "arrow.up.arrow.down"
                )
                coordinateItem(
                    label: "Longitude",
                    value: String(format: "%.6f°", locationManager.longitude),
                    icon: "arrow.left.arrow.right"
                )
            }

            Text("Accuracy: ±\(String(format: "%.1f", locationManager.horizontalAccuracy)) m")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }

    private func coordinateItem(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            Text(value)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.semibold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Details")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 12) {
                detailRow(
                    icon: "mountain.2.fill",
                    label: "Altitude",
                    value: String(format: "%.1f m", locationManager.altitude),
                    accuracy: "±\(String(format: "%.1f", locationManager.verticalAccuracy)) m"
                )

                Divider()

                detailRow(
                    icon: "speedometer",
                    label: "Speed",
                    value: locationManager.formattedSpeed,
                    accuracy: nil
                )

                Divider()

                detailRow(
                    icon: "safari",
                    label: "Heading",
                    value: "\(String(format: "%.1f", max(locationManager.course, 0)))° \(locationManager.cardinalDirection)",
                    accuracy: nil
                )

                Divider()

                detailRow(
                    icon: "clock.fill",
                    label: "Last Update",
                    value: locationManager.timestamp.formatted(date: .omitted, time: .standard),
                    accuracy: nil
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }

    private func detailRow(icon: String, label: String, value: String, accuracy: String?) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            VStack(alignment: .trailing) {
                Text(value)
                    .fontWeight(.medium)
                if let accuracy = accuracy {
                    Text(accuracy)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Address Card

    private var addressCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(.blue)
                Text("Address")
                    .font(.headline)
                Spacer()
            }
            Text(locationManager.address)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }

    // MARK: - Toggle Button

    private var toggleButton: some View {
        Button(action: {
            if locationManager.isUpdating {
                locationManager.stopUpdating()
            } else {
                locationManager.startUpdating()
            }
        }) {
            HStack {
                Image(systemName: locationManager.isUpdating ? "pause.circle.fill" : "play.circle.fill")
                Text(locationManager.isUpdating ? "Stop Tracking" : "Start Tracking")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(locationManager.isUpdating ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
