import SwiftUI

// Matches the Python dashboard colour palette exactly.
extension Color {
    static let veloDark   = Color(hex: "#0d1117")
    static let veloCard   = Color(hex: "#161b22")
    static let veloBorder = Color(hex: "#30363d")
    static let veloOrange = Color(hex: "#f97316")
    static let veloTeal   = Color(hex: "#22d3ee")
    static let veloGreen  = Color(hex: "#4ade80")
    static let veloPurple = Color(hex: "#a78bfa")
    static let veloPink   = Color(hex: "#f472b6")
    static let veloAmber  = Color(hex: "#fbbf24")
    static let veloMuted  = Color(hex: "#8b949e")
    static let veloText   = Color(hex: "#e6edf3")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

func fmtTime(_ hours: Double) -> String {
    let h = Int(hours)
    let m = Int((hours - Double(h)) * 60)
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
}
