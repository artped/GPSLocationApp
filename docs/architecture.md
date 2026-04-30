# Boat GPS Tracking System — Architecture Document

## 1. Overview

A real-time boat tracking system consisting of three components:

1. **iOS App** (Swift/SwiftUI) — Captures GPS coordinates on the boat and transmits them to the backend
2. **Backend API** (Java/Spring Boot) — Receives, stores, and serves location data
3. **Web Map** (HTML/JS + Leaflet) — Displays boat positions and routes on an interactive map

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
                                               │  • Leaflet map      │
                                               │  • Real-time pins   │
                                               │  • Route trails     │
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
| **Frontend** | Leaflet.js | 1.9+ | Interactive map library |
| **Frontend** | HTML/CSS/JS | — | Web map UI |
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
│   │   └── BoatService.java
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

### 3.3 Web Map Frontend

**Responsibilities:**
- Render an interactive map (Leaflet + OpenStreetMap tiles)
- Show boat markers at their latest known position
- Draw route trails from location history
- Auto-refresh via WebSocket or polling

**Pages:**
- **Dashboard** — Map with all active boats
- **Boat Detail** — Single boat view with full route trail and data table

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
| `ws://<server>/ws/locations` | Real-time location updates pushed to map clients |

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

---

## 9. Future Enhancements

- **Geofencing alerts** — Notify when a boat enters/leaves a defined area
- **Speed alerts** — Notify when a boat exceeds a speed threshold
- **Multi-user** — Authentication and authorization for fleet management
- **Trip recording** — Start/stop trip tracking with trip summaries
- **Weather overlay** — Show wind/wave data on the map
- **AIS integration** — Overlay Automatic Identification System data
- **Push notifications** — Alert boat owners of events via APNs
