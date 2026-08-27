import Foundation

/// Punch-force unit can't be read from the FIT file (see BoxingSession.init) —
/// set this to whatever your f3b Boxing app is configured to output on the watch
/// (check its on-device settings). "G", "N", "Kg", or "lbs".
enum BoxingSettings {
    static let punchForceUnit = "N"
}
