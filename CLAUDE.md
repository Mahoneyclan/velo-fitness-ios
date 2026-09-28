# Velo Fitness iOS
Self-contained iPad/iPhone fitness dashboard: cycling data from Strava + Garmin Connect,
and boxing punch metrics parsed from Garmin FIT files. Swift Charts, no server.

## Build (verified 2026-09-28: build OK)
- `xcodebuild -project Sources/VeloFitness/VeloFitness.xcodeproj -scheme VeloFitness -destination 'platform=iOS Simulator,name=iPhone 17' build`
- No test target exists.

## Layout
- `Sources/VeloFitness/VeloFitness/`: **the real app source** (the only folder in the build)
- `Sources/App`, `Sources/Integrations`, `Sources/Models`, `Sources/Views`: older copies,
  tracked in git but NOT compiled. Don't edit them. (inferred; they differ from the live copies)
- `docs/`, `README.md`, `SETUP.md`

## Data layer (no SwiftData)
- Activity data cached as JSON files (FileManager + JSONEncoder); settings and tokens in UserDefaults.
- Strava credentials: `Integrations/Strava/Secrets.swift` (gitignored; copy from `Secrets.swift.example`).

## Rules
- Make changes only under `Sources/VeloFitness/VeloFitness/`. (inferred)
- Garmin/Strava auth code is shared in spirit with velo-films-swift; keep fixes in step
  if asked. (inferred)
