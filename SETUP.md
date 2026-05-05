# Velo Fitness iOS — Setup Guide

SwiftUI iPad dashboard powered by the same Strava & Garmin auth as VeloFilms.

---

## 1. Create Xcode project

1. Open Xcode → **File › New › Project**
2. Choose **iOS › App**
3. Settings:
   - **Product Name:** VeloFitness
   - **Team:** your Apple Developer account
   - **Bundle Identifier:** com.yourname.velofitness
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Minimum Deployment:** iOS 17.0
4. Save it *inside* this repo directory (next to `Sources/`)

---

## 2. Add source files

Drag the entire `Sources/` folder into your Xcode project navigator. When prompted:
- ✅ **Copy items if needed** — unchecked (files are already in the repo)
- ✅ **Create groups**
- ✅ **Add to target:** VeloFitness

---

## 3. Add Strava credentials

Copy `Sources/Integrations/Strava/Secrets.swift` from your VeloFilms project, or create a new one:

```swift
// Sources/Integrations/Strava/Secrets.swift  (gitignored)
enum StravaSecrets {
    static let clientID     = "YOUR_STRAVA_CLIENT_ID"
    static let clientSecret = "YOUR_STRAVA_CLIENT_SECRET"
}
```

The credentials are the **same as VeloFilms** — copy from:
`/Volumes/AData/Github/velo-films-swift/VeloFilms/VeloFilms/Shared/Integrations/Strava/Secrets.swift`

---

## 4. Register the custom URL scheme

In Xcode, select **VeloFitness** target → **Info** tab → expand **URL Types** → click **+**:

| Field            | Value         |
|------------------|---------------|
| Identifier       | velofitness   |
| URL Schemes      | velofitness   |
| Role             | Editor        |

This lets Strava redirect back to the app after OAuth.

---

## 5. Add entitlements (for network access)

In Xcode, select **VeloFitness** target → **Signing & Capabilities** → **+ Capability** → add **App Sandbox** (macOS) or leave as-is for iOS. No special entitlements are required for iOS network calls.

---

## 6. Swift Charts framework

Swift Charts is included with Xcode 14+ for iOS 16+. No additional package is needed.

---

## 7. Build and run on iPad

Select an iPad Simulator or your physical iPad and press **Run** (⌘R).

On first launch:
- Tap the **⟳ Sync** button in the top-right corner
- Choose **Strava** or **Garmin**
- Authenticate once — tokens are cached in UserDefaults
- All rides are fetched (full history, paginated) and stored in the app's Documents folder as `rides.json`

---

## Architecture

```
Sources/
├── App/
│   ├── VeloFitnessApp.swift      # @main entry point
│   └── DesignTokens.swift        # colour palette (matches Python dashboard)
├── Models/
│   ├── Ride.swift                # common schema (Codable, rides.json compatible)
│   ├── RideStore.swift           # @Observable store — load/save/sync/filter
│   └── RideAnalytics.swift       # pure computation for all chart data
├── Integrations/
│   ├── Strava/
│   │   ├── StravaAuth.swift      # OAuth2 via ASWebAuthenticationSession
│   │   ├── StravaClient.swift    # paginated fetch of all activities
│   │   └── Secrets.swift         # ← gitignored, copy from VeloFilms
│   └── Garmin/
│       ├── GarminAuth.swift      # garth SSO flow (OAuth1→OAuth2)
│       └── GarminClient.swift    # paginated fetch of all activities
└── Views/
    ├── DashboardView.swift        # main view — filters, stat cards, all charts
    ├── Components/
    │   └── StatCardView.swift     # reusable stat card + ChartCard wrapper
    ├── Charts/
    │   ├── WeeklyVolumeChart.swift
    │   ├── MonthlyVolumeChart.swift
    │   ├── TrendChart.swift       # reusable scatter + 28d rolling avg
    │   ├── TrainingLoadChart.swift # CTL / ATL / TSB
    │   ├── YearComparisonChart.swift
    │   ├── HeatmapChart.swift
    │   └── HistogramChart.swift
    ├── FitnessTrendView.swift     # 90-day rolling windows table
    ├── PersonalBestsView.swift    # all-time records table
    └── Import/
        ├── StravaImportView.swift # auth + sync all Strava rides
        └── GarminImportView.swift # login form + sync all Garmin rides
```

## Data flow

```
Strava API ──► StravaClient ──► RideStore.syncStrava()
Garmin API ──► GarminClient ──► RideStore.syncGarmin()
                                    │
                               deduplicate()          (same logic as Python extract.py)
                               qualityFilter()        (rides ≥ 1 km and ≥ 5 min)
                                    │
                             rides.json (Documents)   (same format as Python)
                                    │
                              RideAnalytics            (Swift port of dashboard.py analytics)
                                    │
                             Swift Charts views
```

## Migrating existing rides.json from Python

If you already have a `rides.json` from the Python app:
1. Connect your iPad to Mac via Finder
2. Navigate to VeloFitness app → Files
3. Drop `rides.json` in — the app loads it on startup

Or use **Files** app on iPad with iCloud Drive.
