# Velo Fitness iOS

A native, fully self-contained iPad multi-sport dashboard — no server, no Python, no Mac
required to keep it running. A cycling tab pulls your full ride history from **Strava**
and **Garmin Connect** (a complete port of the
[Velo Fitness Python dashboard](https://github.com/Mahoneyclan/velo_fitness)), and a boxing
tab pulls punch metrics directly from Garmin, parsing the FIT file's developer fields
(recorded by the f3b Boxing/Kick Boxing Connect IQ app) with a small hand-written FIT
parser built into the app. Both tabs render with Swift Charts and sync entirely on-device.

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

### Boxing tab
Tap **Sync** on the Boxing tab (reuses the Garmin session already signed in from the
Cycling tab — no separate login) to fetch boxing/kickboxing activities, download each
one's original FIT file directly from Garmin, and parse punch metrics out of its
developer fields on-device. Everything — auth, download, parsing, storage — happens on
the phone/iPad; nothing runs anywhere else.

| Chart | What it shows |
|-------|---------------|
| Punch Rate Trend | Per-session avg punches/min scatter + 28-day rolling average |
| Punch Force Trend | Per-session max punch force scatter + 28-day rolling average, all-time PB in the stat row |
| Heart Rate Trend | Per-session avg HR scatter + 28-day rolling average |
| Jab / Hook / Cross Mix | Grouped bar of punch-type counts per session |
| Jab / Hook / Cross Share | 100%-stacked column of punch-type mix per session |
| Session Duration | Bar of minutes trained per session |

Punch force is shown in whichever unit `BoxingSettings.punchForceUnit`
(`Models/BoxingSettings.swift`) is set to — it is **not** auto-detected or converted
between units. The FIT file's own `units` string for every force field is just the app's
static label `"G,N,Kg | lbs"`, not the unit actually selected on the watch — there is no
way to recover that from the file. Set `BoxingSettings.punchForceUnit` to whatever your
f3b app's on-device setting actually is.

Field names (`pRate`, `tPunch`, `mForce`, `Force`, `vForce`, etc.) were verified
byte-for-byte against a real f3b export before being hardcoded into
`FITBoxingParser.swift` — not guessed. If a future f3b firmware update renames them,
the parser will simply stop finding those fields (sessions still sync, with those
metrics blank) rather than crashing.

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

### 4. Add the Boxing tab's source files

`Models/BoxingSession.swift`, `Models/BoxingStore.swift`, `Models/BoxingAnalytics.swift`,
`Models/BoxingSettings.swift`, `Integrations/Garmin/FITBoxingParser.swift`, and everything
under `Views/Boxing/` were added on disk but aren't part of the `.xcodeproj` yet — drag
them into the project navigator (same as step 1) so they compile into the VeloFitness
target.

No iCloud capability, no entitlements, no second account setup — boxing syncs the same
way cycling does, straight from Garmin.

### 5. Build and run

Select an iPad Simulator or your device, press **⌘R**. On the Cycling tab, tap **⟳ Sync**
→ **Sync Garmin** and sign in once — the Boxing tab's **⟳ Sync** button reuses that same
session to pull boxing activities.

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
│   ├── RideAnalytics.swift        # pure analytics: rolling avgs, CTL/ATL/TSB, etc.
│   ├── BoxingSession.swift        # boxing schema, built from FITBoxingParser output
│   ├── BoxingStore.swift          # @Observable — syncs Garmin, parses FIT, local storage
│   ├── BoxingAnalytics.swift      # trend series + jab/hook/cross mix
│   └── BoxingSettings.swift       # punch-force display unit (can't be read from the FIT file)
│
├── Integrations/
│   ├── Strava/
│   │   ├── StravaAuth.swift       # OAuth 2 + token refresh
│   │   ├── StravaClient.swift     # paginated activity fetch (200/page)
│   │   └── Secrets.swift          # ← gitignored
│   └── Garmin/
│       ├── GarminAuth.swift       # garth SSO: cookie → OAuth1 → OAuth2
│       ├── GarminClient.swift     # paginated activity fetch (100/page) + FIT download
│       └── FITBoxingParser.swift  # hand-written FIT binary parser (dev fields) + zip reader
│
└── Views/
    ├── DashboardView.swift         # cycling root view — toolbar, stat cards, chart grid
    ├── Components/
    │   └── StatCardView.swift      # stat card + ChartCard reusable wrappers (shared by both tabs)
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
    ├── Import/
    │   ├── StravaImportView.swift  # OAuth flow + one-tap full sync
    │   └── GarminImportView.swift  # login form + one-tap full sync
    └── Boxing/
        ├── BoxingDashboardView.swift    # boxing root view — stat cards, chart grid, session list
        ├── BoxingTrendChart.swift       # punch rate / punch force / HR trend (TrendPoint-based)
        ├── PunchMixChart.swift          # jab/hook/cross grouped bar (raw counts)
        ├── PunchMixShareChart.swift     # jab/hook/cross 100%-stacked column (share)
        ├── BoxingVolumeChart.swift      # session duration bar
        └── BoxingSessionListView.swift  # session list + detail view
```

Boxing data flow (entirely on-device, same Garmin session as cycling):
```
Garmin Connect (activity list) ──► GarminClient.activities()  ─┐
                                                                 ├─► filter isBoxing
Garmin Connect (FIT download)  ──► GarminClient.downloadOriginalFIT() ─┘
                                              │
                                       ZipReader.unzipFirstEntry()
                                              │
                                     FITBoxingParser.parse()  (dev fields)
                                              │
                              BoxingStore ──► boxing_sessions.json (Documents/)
                                              │
                                       Boxing tab (Swift Charts)
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
