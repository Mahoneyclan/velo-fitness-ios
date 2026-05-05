import Foundation
import AuthenticationServices

// Adapted from VeloFilms — URL scheme changed to "velofitness".
@MainActor
final class StravaAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = StravaAuth()

    private let clientID     = StravaSecrets.clientID
    private let clientSecret = StravaSecrets.clientSecret
    private let redirectURI  = "velofitness://localhost/strava"
    private let scope        = "activity:read_all"

    private(set) var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "stravaAccessToken") }
        set { UserDefaults.standard.set(newValue, forKey: "stravaAccessToken") }
    }
    private(set) var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "stravaRefreshToken") }
        set { UserDefaults.standard.set(newValue, forKey: "stravaRefreshToken") }
    }
    private var tokenExpiry: Date? {
        get { UserDefaults.standard.object(forKey: "stravaTokenExpiry") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "stravaTokenExpiry") }
    }

    var isAuthenticated: Bool { accessToken != nil }

    func ensureValidToken() async throws -> String {
        if let token = accessToken,
           let expiry = tokenExpiry,
           expiry > Date().addingTimeInterval(300) {
            return token
        }
        if let refresh = refreshToken {
            return try await refreshAccessToken(refresh)
        }
        throw StravaError.noToken
    }

    private func refreshAccessToken(_ refresh: String) async throws -> String {
        var req = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode([
            "client_id": clientID, "client_secret": clientSecret,
            "refresh_token": refresh, "grant_type": "refresh_token",
        ])
        let (data, _) = try await URLSession.shared.data(for: req)
        let r = try JSONDecoder().decode(TokenResponse.self, from: data)
        storeTokens(r)
        return r.accessToken
    }

    func authenticate() async throws -> String {
        var comps = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")!
        comps.queryItems = [
            .init(name: "client_id",      value: clientID),
            .init(name: "redirect_uri",   value: redirectURI),
            .init(name: "response_type",  value: "code"),
            .init(name: "approval_prompt",value: "auto"),
            .init(name: "scope",          value: scope),
        ]

        let callbackURL = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: comps.url!,
                callbackURLScheme: "velofitness"
            ) { url, error in
                if let error { cont.resume(throwing: error); return }
                guard let url else { cont.resume(throwing: StravaError.missingCallbackURL); return }
                cont.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else { throw StravaError.missingCode }

        return try await exchangeCode(code)
    }

    func signOut() { accessToken = nil; refreshToken = nil; tokenExpiry = nil }

    private func exchangeCode(_ code: String) async throws -> String {
        var req = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode([
            "client_id": clientID, "client_secret": clientSecret,
            "code": code, "grant_type": "authorization_code",
        ])
        let (data, _) = try await URLSession.shared.data(for: req)
        let r = try JSONDecoder().decode(TokenResponse.self, from: data)
        storeTokens(r)
        return r.accessToken
    }

    private func storeTokens(_ r: TokenResponse) {
        accessToken  = r.accessToken
        refreshToken = r.refreshToken
        tokenExpiry  = Date(timeIntervalSince1970: Double(r.expiresAt))
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first ?? UIWindow()
    }

    private struct TokenResponse: Decodable {
        var accessToken: String; var refreshToken: String; var expiresAt: Int
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresAt = "expires_at"
        }
    }
}

enum StravaError: LocalizedError {
    case missingCallbackURL, missingCode, noToken, httpError(Int)
    var errorDescription: String? {
        switch self {
        case .missingCallbackURL: return "Strava OAuth returned no callback URL"
        case .missingCode:        return "Strava OAuth callback missing code"
        case .noToken:            return "Not authenticated with Strava"
        case .httpError(let c):   return "Strava API error (HTTP \(c))"
        }
    }
}
