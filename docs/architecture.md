# Boat GPS Tracking System — Architecture Document

## 1. Overview

A real-time boat tracking system consisting of three components:

1. **iOS App** (Swift/SwiftUI) — Captures GPS coordinates on the boat and transmits them to the backend
2. **Backend API** (Java/Spring Boot) — Receives, stores, and serves location data
3. **Web Map** (HTML/JS + Google Maps) — Displays boat positions and routes on an interactive map
4. **KML Export** — Generate KML/KMZ files for 3D route replay in Google Earth

```
┌─────────────────┐        HTTPS/JSON         ┌─────────────────────┐
│                 │  POST /api/v1/locations    │                     │
│   iOS App       │ ─────────────────────────► │   Spring Boot API   │
│   (on boat)     │                            │                     │
│                 │                            │  ┌───────────────┐  │
│  • GPS capture  │                            │  │  PostgreSQL   │  │
│  • Auto-send    │                            │  │  + PostGIS    │  │
│  • Offline queue│                            │  └───────────────┘  │
└─────────────────┘                            │                     │
                                               └──────────┬──────────┘
                                                          │
                                            GET /api/v1/* │ WebSocket
                                                          │
                                               ┌──────────▼──────────┐
                                               │                     │
                                               │   Web Map Frontend  │
                                               │                     │
                                               │  • Google Maps      │
                                               │  • Real-time pins   │
                                               │  • Route trails     │
                                               │  • KML/KMZ export   │
                                               └─────────────────────┘
```

---

## 2. Technology Stack

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **Mobile** | Swift / SwiftUI | 5.9+ | iOS app for GPS capture |
| **Mobile** | CoreLocation | iOS 17+ | GPS hardware access |
| **Backend** | Java | 21 LTS | Backend language |
| **Backend** | Spring Boot | 3.2+ | REST API framework |
| **Backend** | Spring Data JPA | 3.2+ | Database ORM |
| **Backend** | Spring WebSocket | 3.2+ | Real-time push to web clients |
| **Database** | PostgreSQL | 16+ | Relational database |
| **Database** | PostGIS | 3.4+ | Geospatial extensions |
| **Frontend** | Google Maps JS API | 3.x | Interactive map with satellite/terrain views |
| **Frontend** | HTML/CSS/JS | — | Web map UI |
| **Backend** | JAK XML (JAXB) | — | KML/KMZ generation for Google Earth export |
| **Infra** | Docker / Docker Compose | — | Local development & deployment |
| **Infra** | Flyway | 10+ | Database migrations |

---

## 3. Component Details

### 3.1 iOS App (Swift/SwiftUI)

**Responsibilities:**
- Capture GPS coordinates via `CLLocationManager`
- Display current position on the iPhone screen
- Transmit location updates to the backend via HTTP POST
- Queue location updates when offline and send when connectivity is restored
- Configurable settings: API URL, boat ID, send interval

**Key Classes:**

| Class | Responsibility |
|-------|---------------|
| `LocationManager` | CoreLocation wrapper, GPS updates (already built) |
| `APIService` | HTTP POST to backend, retry logic, offline queue |
| `SettingsView` | Configure API URL, boat ID, send interval |
| `ContentView` | Main UI — coordinates, status, send controls |

**Offline Queue Strategy:**
- Store unsent locations in `UserDefaults` or Core Data
- On connectivity restore, flush queue in chronological order
- Maximum queue size: 10,000 entries (~2 MB)

---

### 3.2 Backend API (Java / Spring Boot)

**Responsibilities:**
- Receive GPS location data from one or more boats
- Persist location history in PostgreSQL with PostGIS geometry
- Serve REST endpoints for querying current and historical positions
- Push real-time updates to web clients via WebSocket

**Project Structure:**

```
boat-tracker-api/
├── src/main/java/com/boattracker/
│   ├── BoatTrackerApplication.java
│   ├── config/
│   │   ├── WebSocketConfig.java
│   │   └── CorsConfig.java
│   ├── controller/
│   │   ├── LocationController.java
│   │   └── BoatController.java
│   ├── dto/
│   │   ├── LocationRequest.java
│   │   ├── LocationResponse.java
│   │   └── BoatResponse.java
│   ├── entity/
│   │   ├── Boat.java
│   │   └── Location.java
│   ├── repository/
│   │   ├── BoatRepository.java
│   │   └── LocationRepository.java
│   ├── service/
│   │   ├── LocationService.java
│   │   ├── BoatService.java
│   │   └── KmlExportService.java
│   └── websocket/
│       └── LocationWebSocketHandler.java
├── src/main/resources/
│   ├── application.yml
│   └── db/migration/
│       ├── V1__create_boats_table.sql
│       └── V2__create_locations_table.sql
├── pom.xml
└── Dockerfile
```

---

### 3.3 Web Map Frontend (Google Maps)

**Responsibilities:**
- Render an interactive map using **Google Maps JavaScript API**
- Show boat markers (custom sailboat icon, rotated by heading) at their latest known position
- Draw route polylines from location history, color-coded by speed
- Auto-refresh via WebSocket for real-time marker updates
- Support Satellite, Terrain, Hybrid, and Roadmap views

**Pages:**
- **Dashboard** — Map with all active boats, zoom-to-fit
- **Boat Detail** — Single boat view with full route trail, data table, and KML export button

**Google Maps Features Used:**
- `google.maps.Map` — Base map with satellite/terrain
- `google.maps.Marker` / `google.maps.marker.AdvancedMarkerElement` — Custom sailboat icon
- `google.maps.Polyline` — Route trail drawing
- `google.maps.InfoWindow` — Popup with speed, heading, timestamp on marker click
- `google.maps.LatLngBounds` — Auto-fit map to show all boats

**API Key Requirement:**
- A Google Maps API key is required (enable "Maps JavaScript API" at [Google Cloud Console](https://console.cloud.google.com/apis/credentials))
- The key is loaded via `<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_KEY">`

---

### 3.4 KML/KMZ Export (Google Earth)

**Responsibilities:**
- Generate KML files from boat route history for 3D replay in Google Earth
- Include placemarks with boat name, timestamps, speed, and heading
- Draw `<LineString>` route path with altitude data
- Support time-based animation via `<TimeStamp>` elements
- Optionally compress as KMZ (zipped KML + icons)

**KML Structure:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Sea Explorer — 2025-01-15</name>
    <description>Sailboat route trail</description>
    
    <Style id="boatTrail">
      <LineStyle>
        <color>ff0000ff</color>
        <width>3</width>
      </LineStyle>
    </Style>
    
    <!-- Route trail -->
    <Placemark>
      <name>Route</name>
      <styleUrl>#boatTrail</styleUrl>
      <LineString>
        <altitudeMode>clampToSeaFloor</altitudeMode>
        <coordinates>
          -46.633308,-23.550520,0.5
          -46.634000,-23.551000,0.3
          ...
        </coordinates>
      </LineString>
    </Placemark>
    
    <!-- Individual points with timestamps -->
    <Placemark>
      <name>14:30:00 — 12.3 km/h</name>
      <TimeStamp><when>2025-01-15T14:30:00Z</when></TimeStamp>
      <Point>
        <coordinates>-46.633308,-23.550520,0.5</coordinates>
      </Point>
    </Placemark>
    
  </Document>
</kml>
```

**Usage:**
1. User clicks "Export KML" on the web dashboard for a specific boat/trip
2. Backend generates the KML file from stored location data
3. Browser downloads the `.kml` file
4. User opens it in Google Earth for 3D replay with time slider

---

## 4. Database Schema

### Tables

```sql
-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Boats registry
CREATE TABLE boats (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          VARCHAR(255) NOT NULL,
    description   VARCHAR(500),
    created_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Location history
CREATE TABLE locations (
    id                    BIGSERIAL PRIMARY KEY,
    boat_id               UUID NOT NULL REFERENCES boats(id),
    latitude              DOUBLE PRECISION NOT NULL,
    longitude             DOUBLE PRECISION NOT NULL,
    altitude              DOUBLE PRECISION,
    speed                 DOUBLE PRECISION,
    course                DOUBLE PRECISION,
    horizontal_accuracy   DOUBLE PRECISION,
    vertical_accuracy     DOUBLE PRECISION,
    address               VARCHAR(500),
    device_timestamp      TIMESTAMP WITH TIME ZONE NOT NULL,
    received_at           TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    geom                  GEOMETRY(Point, 4326),

    CONSTRAINT fk_boat FOREIGN KEY (boat_id) REFERENCES boats(id)
);

-- Indexes for performance
CREATE INDEX idx_locations_boat_id ON locations(boat_id);
CREATE INDEX idx_locations_device_timestamp ON locations(boat_id, device_timestamp DESC);
CREATE INDEX idx_locations_geom ON locations USING GIST(geom);
```

### Entity Relationship Diagram

```
┌──────────────┐       1:N       ┌──────────────────┐
│    boats     │ ──────────────► │    locations      │
├──────────────┤                 ├──────────────────┤
│ id (UUID PK) │                 │ id (BIGSERIAL PK)│
│ name         │                 │ boat_id (FK)     │
│ description  │                 │ latitude         │
│ created_at   │                 │ longitude        │
│ updated_at   │                 │ altitude         │
└──────────────┘                 │ speed            │
                                 │ course           │
                                 │ h_accuracy       │
                                 │ v_accuracy       │
                                 │ address          │
                                 │ device_timestamp │
                                 │ received_at      │
                                 │ geom (PostGIS)   │
                                 └──────────────────┘
```

---

## 5. API Contracts

### Base URL: `https://<server>/api/v1`

### 5.1 Boats

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/boats` | Register a new boat |
| `GET` | `/boats` | List all boats |
| `GET` | `/boats/{id}` | Get boat details |

#### POST /boats
```json
// Request
{
  "name": "Sea Explorer",
  "description": "Fishing boat - Marina São Paulo"
}

// Response (201 Created)
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "name": "Sea Explorer",
  "description": "Fishing boat - Marina São Paulo",
  "created_at": "2025-01-15T10:00:00Z"
}
```

### 5.2 Locations

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/locations` | Submit a GPS location update |
| `POST` | `/locations/batch` | Submit multiple location updates (offline queue flush) |
| `GET` | `/boats/{id}/locations/latest` | Get the most recent location for a boat |
| `GET` | `/boats/{id}/locations` | Get location history (paginated) |
| `GET` | `/boats/{id}/locations/trail` | Get location trail for map rendering |

#### POST /locations
```json
// Request
{
  "boat_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "latitude": -23.550520,
  "longitude": -46.633308,
  "altitude": 0.5,
  "speed": 12.3,
  "course": 180.0,
  "horizontal_accuracy": 5.0,
  "vertical_accuracy": 3.0,
  "address": "Santos Bay, São Paulo, Brazil",
  "device_timestamp": "2025-01-15T14:30:00.000Z"
}

// Response (201 Created)
{
  "id": 12345,
  "boat_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "latitude": -23.550520,
  "longitude": -46.633308,
  "altitude": 0.5,
  "speed": 12.3,
  "course": 180.0,
  "horizontal_accuracy": 5.0,
  "vertical_accuracy": 3.0,
  "address": "Santos Bay, São Paulo, Brazil",
  "device_timestamp": "2025-01-15T14:30:00.000Z",
  "received_at": "2025-01-15T14:30:01.234Z"
}
```

#### POST /locations/batch
```json
// Request
{
  "locations": [
    {
      "boat_id": "a1b2c3d4-...",
      "latitude": -23.5505,
      "longitude": -46.6333,
      "device_timestamp": "2025-01-15T14:30:00Z",
      ...
    },
    {
      "boat_id": "a1b2c3d4-...",
      "latitude": -23.5510,
      "longitude": -46.6340,
      "device_timestamp": "2025-01-15T14:30:05Z",
      ...
    }
  ]
}

// Response (201 Created)
{
  "received": 2,
  "failed": 0
}
```

#### GET /boats/{id}/locations/latest
```json
// Response (200 OK)
{
  "id": 12345,
  "boat_id": "a1b2c3d4-...",
  "latitude": -23.550520,
  "longitude": -46.633308,
  "altitude": 0.5,
  "speed": 12.3,
  "course": 180.0,
  "address": "Santos Bay, São Paulo, Brazil",
  "device_timestamp": "2025-01-15T14:30:00Z",
  "received_at": "2025-01-15T14:30:01Z"
}
```

#### GET /boats/{id}/locations?from=&to=&page=&size=
```json
// Response (200 OK)
{
  "content": [ ... ],
  "page": 0,
  "size": 50,
  "total_elements": 1234,
  "total_pages": 25
}
```

#### GET /boats/{id}/locations/trail?from=&to=
```json
// Response (200 OK) — Simplified for map rendering
{
  "boat_id": "a1b2c3d4-...",
  "boat_name": "Sea Explorer",
  "points": [
    { "lat": -23.5505, "lng": -46.6333, "ts": "2025-01-15T14:30:00Z", "speed": 12.3 },
    { "lat": -23.5510, "lng": -46.6340, "ts": "2025-01-15T14:30:05Z", "speed": 13.1 },
    ...
  ]
}
```

### 5.3 WebSocket

| Endpoint | Description |
|----------|-------------|
| `ws://<server>/ws/locations` | Real-time location updates pushed to Google Maps clients |

**Message format (server → client):**
```json
{
  "type": "LOCATION_UPDATE",
  "boat_id": "a1b2c3d4-...",
  "boat_name": "Sea Explorer",
  "latitude": -23.550520,
  "longitude": -46.633308,
  "speed": 12.3,
  "course": 180.0,
  "device_timestamp": "2025-01-15T14:30:00Z"
}
```

The web frontend receives this via WebSocket and updates the `google.maps.Marker` position and `google.maps.Polyline` path in real time.

### 5.4 KML Export

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/boats/{id}/locations/kml?from=&to=` | Download route as KML file for Google Earth |

**Query Parameters:**
- `from` (optional) — Start datetime (ISO 8601). Defaults to 24 hours ago.
- `to` (optional) — End datetime (ISO 8601). Defaults to now.

**Response:**
- `Content-Type: application/vnd.google-earth.kml+xml`
- `Content-Disposition: attachment; filename="sea-explorer-2025-01-15.kml"`

The backend queries the `locations` table for the given boat and time range, then generates a KML document with:
- `<LineString>` for the full route trail
- `<Placemark>` with `<TimeStamp>` for each recorded point (enables Google Earth time slider)
- `<Style>` for route color and width
- `altitudeMode` set to `clampToSeaFloor` for maritime accuracy

---

## 6. Data Flow

```
 iPhone (on boat)                Backend (Spring Boot)              Web Browser
 ────────────────                ─────────────────────              ───────────
       │                                  │                             │
       │  1. GPS update received          │                             │
       │  (CLLocationManager)             │                             │
       │                                  │                             │
       │  2. POST /api/v1/locations       │                             │
       │ ───────────────────────────────► │                             │
       │                                  │  3. Validate & persist      │
       │                                  │     to PostgreSQL           │
       │                                  │                             │
       │                                  │  4. Broadcast via WebSocket │
       │                                  │ ──────────────────────────► │
       │                                  │                             │
       │           201 Created            │                             │  5. Update map
       │ ◄─────────────────────────────── │                             │     marker
       │                                  │                             │
```

**Offline scenario:**
```
 iPhone (no signal)              Backend                            Web Browser
 ──────────────────              ───────                            ───────────
       │                                  │                             │
       │  1. GPS update received          │                             │
       │  2. Queue locally (Core Data)    │                             │
       │  3. ... more updates queued ...  │                             │
       │                                  │                             │
       │  ── Signal restored ──           │                             │
       │                                  │                             │
       │  4. POST /api/v1/locations/batch │                             │
       │ ───────────────────────────────► │                             │
       │                                  │  5. Persist all             │
       │           201 Created            │  6. Broadcast latest        │
       │ ◄─────────────────────────────── │ ──────────────────────────► │
       │                                  │                             │
```

---

## 7. Deployment Architecture

### Development (Local)

```
┌──────────────────────────────────────────────┐
│                Docker Compose                 │
│                                               │
│  ┌─────────────┐   ┌──────────────────────┐  │
│  │  PostgreSQL  │   │  Spring Boot API     │  │
│  │  + PostGIS   │   │  (port 8080)         │  │
│  │  (port 5432) │   │                      │  │
│  └─────────────┘   └──────────────────────┘  │
│                                               │
│  ┌──────────────────────────────────────────┐ │
│  │  Web Frontend (nginx, port 3000)         │ │
│  └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

### Production (Cloud)

| Component | Suggested Platform |
|-----------|--------------------|
| Backend API | AWS ECS / Railway / Fly.io |
| Database | AWS RDS (PostgreSQL + PostGIS) / Supabase |
| Web Frontend | Vercel / Netlify / S3 + CloudFront |
| iOS App | App Store / TestFlight |

---

## 8. Security Considerations

| Concern | Solution |
|---------|----------|
| API Authentication | API key per boat (sent as `X-API-Key` header) |
| HTTPS | TLS for all communication |
| Input Validation | Validate coordinate ranges, timestamps, boat ownership |
| Rate Limiting | Max 1 request/second per boat to prevent abuse |
| CORS | Restrict to frontend domain |
| Database | Parameterized queries via JPA (no SQL injection) |
| Google Maps API Key | Restrict key by HTTP referrer and API (Maps JS only) |

---

## 9. Future Enhancements

- **Geofencing alerts** — Notify when a boat enters/leaves a defined area
- **Speed alerts** — Notify when a boat exceeds a speed threshold
- **Multi-user** — Authentication and authorization for fleet management
- **Trip recording** — Start/stop trip tracking with trip summaries
- **Weather overlay** — Show wind/wave data on the map (Google Maps overlay layers)
- **AIS integration** — Overlay Automatic Identification System data
- **Push notifications** — Alert boat owners of events via APNs
- **KMZ with custom icons** — Bundle sailboat icons inside KMZ archives for richer Google Earth display
- **Google Maps heatmap** — Speed/density heatmap layer using `google.maps.visualization`
