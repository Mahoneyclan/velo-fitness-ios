# Velo Fitness iOS

A native iPad cycling dashboard that pulls your full ride history from **Strava** and **Garmin Connect** and visualises it with Swift Charts — a complete port of the [Velo Fitness Python dashboard](https://github.com/Mahoneyclan/velo_fitness).

---

## Screenshots

> _Add screenshots here after first build._

---

## Features

### Data sources
| Source | Auth method | What's synced |
|--------|-------------|---------------|
| **Strava** | OAuth 2 via `ASWebAuthenticationSession` (in-app, no browser redirect) | All cycling activities — full history, paginated 200/page |
| **Garmin Connect** | garth SSO (email + password → OAuth 1 → OAuth 2) | All cycling activities — full history, paginated 100/page |

Both sources are deduplicated automatically: rides on the same date within 10% distance are merged, Strava record preferred (richer metadata).

### Dashboard charts
| Chart | What it shows |
|-------|---------------|
| Weekly Volume | Distance bars + riding time line |
| Monthly Volume | Distance bars + elevation line |
| Speed Trend | Per-ride avg speed scatter + 28-day rolling average |
| Heart Rate Trend | Per-ride avg HR scatter + 28-day rolling average |
| Power Trend | Per-ride avg watts scatter + 28-day rolling average |
| Cadence Trend | Per-ride avg cadence scatter + 28-day rolling average |
| Training Load | Weekly load bars · CTL (fitness) · ATL (fatigue) · TSB (form) |
| Year Comparison | Cumulative distance by day-of-year, all years overlaid |
| Annual Heatmap | Ride volume by week × year |
| Ride Distribution | Histogram of ride distances |
| Fitness Trend | 90-day rolling windows — rides, distance, avg speed, avg HR, efficiency score, climbing |
| Personal Bests | All-time records: longest ride, most elevation, fastest avg speed, highest power, longest session, lowest HR |

### Filters
- **Time range** — All time · This year · Last 3 / 6 / 12 months · Last 2 / 3 / 5 years
- **Ride type** — All · Outdoor only · Indoor only · Commutes only · No commutes

### Data quality
Matches the Python dashboard exactly:
- Rides shorter than 1 km or 5 minutes are dropped
- Implausible values are nulled rather than dropping the whole ride (avg speed > 60 km/h, avg power > 600 W, avg HR < 70 or > 220 bpm, cadence < 20 rpm)

---

## Requirements

| Requirement | Minimum |
|-------------|---------|
| Xcode | 15+ |
| iOS / iPadOS | 17.0+ |
| Swift | 5.9+ |
| Apple Developer account | Free tier works for local device testing |
| Strava account | Optional |
| Garmin Connect account | Optional (MFA must be disabled) |

---

## Setup

Full instructions are in [`SETUP.md`](SETUP.md). The short version:

### 1. Clone and open in Xcode

```bash
git clone https://github.com/Mahoneyclan/velo-fitness-ios.git
cd velo-fitness-ios
```

Open Xcode → **File › New › Project › iOS App**, save it inside this directory, then drag the `Sources/` folder into the project navigator.

### 2. Add credentials

Create `Sources/Integrations/Strava/Secrets.swift` (gitignored):

```swift
enum StravaSecrets {
    static let clientID     = "YOUR_STRAVA_CLIENT_ID"
    static let clientSecret = "YOUR_STRAVA_CLIENT_SECRET"
}
```

Get your credentials at [strava.com/settings/api](https://www.strava.com/settings/api). Set the **Authorization Callback Domain** to `localhost`.

Garmin uses email + password directly — no API key required.

### 3. Register the URL scheme

In Xcode: target → **Info** → **URL Types** → **+**

| Field | Value |
|-------|-------|
| Identifier | velofitness |
| URL Schemes | velofitness |

### 4. Build and run

Select an iPad Simulator or your device, press **⌘R**, and tap the **⟳ Sync** button.

---

## Architecture

```
Sources/
├── App/
│   ├── VeloFitnessApp.swift       # @main, injects RideStore
│   └── DesignTokens.swift         # colour palette (dark theme, matches Python)
│
├── Models/
│   ├── Ride.swift                 # common ride schema, Codable with rides.json
│   ├── RideStore.swift            # @Observable — load/save/sync/filter
│   └── RideAnalytics.swift        # pure analytics: rolling avgs, CTL/ATL/TSB, etc.
│
├── Integrations/
│   ├── Strava/
│   │   ├── StravaAuth.swift       # OAuth 2 + token refresh
│   │   ├── StravaClient.swift     # paginated activity fetch (200/page)
│   │   └── Secrets.swift          # ← gitignored
│   └── Garmin/
│       ├── GarminAuth.swift       # garth SSO: cookie → OAuth1 → OAuth2
│       └── GarminClient.swift     # paginated activity fetch (100/page)
│
└── Views/
    ├── DashboardView.swift         # root view — toolbar, stat cards, chart grid
    ├── Components/
    │   └── StatCardView.swift      # stat card + ChartCard reusable wrappers
    ├── Charts/                     # one file per chart, all use Swift Charts
    │   ├── WeeklyVolumeChart.swift
    │   ├── MonthlyVolumeChart.swift
    │   ├── TrendChart.swift        # reusable for speed / HR / power / cadence
    │   ├── TrainingLoadChart.swift
    │   ├── YearComparisonChart.swift
    │   ├── HeatmapChart.swift
    │   └── HistogramChart.swift
    ├── FitnessTrendView.swift
    ├── PersonalBestsView.swift
    └── Import/
        ├── StravaImportView.swift  # OAuth flow + one-tap full sync
        └── GarminImportView.swift  # login form + one-tap full sync
```

### Data flow

```
Strava API ──► StravaClient  ─┐
                               ├─► RideStore ──► deduplicate() ──► rides.json
Garmin API ──► GarminClient  ─┘                 qualityFilter()   (Documents/)
                                                      │
                                               RideAnalytics
                                                      │
                                            Swift Charts views
```

`rides.json` is stored in the app's Documents folder using the **exact same schema** as the Python `extract.py` output — so you can copy an existing `rides.json` straight from the Python project into the iPad app via Files / Finder.

---

## Relationship to other Velo projects

| Repo | Purpose |
|------|---------|
| [`velo_fitness`](https://github.com/Mahoneyclan/velo_fitness) | Python CLI data extractor + Plotly Dash web dashboard (the original) |
| [`velo-films-swift`](https://github.com/Mahoneyclan/velo-films-swift) | Swift cycling film editor — source of `StravaAuth` and `GarminAuth` used here |
| **`velo-fitness-ios`** ← you are here | Native iPad dashboard built from the above two |

The Strava and Garmin auth code is ported directly from `velo-films-swift` with minimal changes (URL scheme renamed to `velofitness://`). Credentials are shared — the same Strava app registration covers both.

---

## Migrating existing Python data

If you already have rides from the Python app:

1. Connect iPad to Mac via Finder (or use iCloud Drive / AirDrop)
2. Navigate to **VeloFitness** → **Files** in Finder
3. Drop your `rides.json` in
4. Relaunch the app — it loads the file on startup

Any subsequent sync will merge new rides in, deduplicating against what's already there.

---

## Licence

MIT
