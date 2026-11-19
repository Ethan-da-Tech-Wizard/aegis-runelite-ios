// ==============================================================================
// Program: JagexOAuthManager.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Zero-Credential Jagex Account OAuth2 PKCE Authentication Engine.
//          Implements RFC 7636 (Proof Key for Code Exchange) using Apple's
//          ASWebAuthenticationSession to securely authenticate Old School
//          RuneScape players without storing, observing, or handling raw passwords.
// ==============================================================================

// ==============================================================================
// Architecture Overview & Cryptographic Protocol Engineering:
// ==============================================================================
// In modern web and mobile security, "Zero-Credential Architecture" means a
// third-party application NEVER asks for, handles, or stores the user's password.
//
// Why OAuth2 with PKCE (RFC 7636) is Required:
// Standard OAuth2 authorization code flows were originally designed for web servers
// capable of maintaining a confidential client_secret. Mobile native apps, however,
// are "public clients" because any secret embedded in an app binary can be extracted
// by reverse engineering.
//
// How PKCE Solves This:
// 1. Code Verifier: The client generates 32 cryptographically random bytes using
//    the OS hardware random number generator (`SecRandomCopyBytes`) and converts
//    it to a URL-safe Base64 string.
// 2. Code Challenge: The client computes the SHA-256 cryptographic hash of the
//    verifier: `Base64URL(SHA256(code_verifier))`.
// 3. Authorization Request: The app sends ONLY the `code_challenge` to Jagex's
//    authorization server (`https://account.jagex.com/oauth2/auth`).
// 4. Isolated Browser Session: Apple's `ASWebAuthenticationSession` presents Jagex's
//    official login webpage in a secure sandbox isolated from our app's memory.
// 5. Code Exchange: Jagex redirects back to `runelite-mobile://oauth-callback?code=...`.
//    The app sends the original `code_verifier` in an HTTPS POST request.
//    Jagex hashes the verifier and verifies it matches the previously stored challenge!
//    This cryptographically guarantees that intercepted authorization codes cannot
//    be stolen by malicious apps.
// ==============================================================================

import Foundation
import AuthenticationServices
import CommonCrypto

/// Jagex OAuth2 Token response structure containing access tokens and session data.
// Field names map from the OAuth2 snake_case JSON keys via CodingKeys below.
public struct JagexTokenResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let idToken: String?
    public let tokenType: String
    public let expiresIn: Int
    public let gameToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case gameToken = "game_token"
    }
}

/// Zero-Credential Jagex Account OAuth2 PKCE Authentication Engine.
public final class JagexOAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    /// Shared singleton manager accessible throughout the application.
    public static let shared = JagexOAuthManager()

    // Official Jagex Identity Provider Endpoints
    // Endpoint, client id and scopes are hard-coded constants (not secrets). The client id is the app's own claim and must match
    // whatever the identity provider actually registered; verify it before relying on this flow.
    public static let authorizeURL = "https://account.jagex.com/oauth2/auth"
    public static let tokenURL = "https://account.jagex.com/oauth2/token"
    public static let clientId = "oldschool-runescape-mobile-ios"
    public static let redirectUri = "runelite-mobile://oauth-callback"
    public static let scopes = "openid offline gametoken"

    // Observable published properties binding authentication state directly to SwiftUI views
    // @Published properties are mutated only on the main queue so SwiftUI observers update safely.
    @Published public var isAuthenticated: Bool = false
    @Published public var characterName: String? = nil
    @Published public var isAuthenticating: Bool = false
    @Published public var authError: String? = nil

    // The PKCE verifier lives only in memory for the duration of one login attempt.
    private var currentCodeVerifier: String?
    private var authSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        checkExistingAuth()
    }

    /// Check if a valid refresh token exists in the Keychain from a previous session.
    // Presence of a non-empty refresh token is treated as 'signed in'. The token is not validated or refreshed here, and the
    // displayed character name is a placeholder string, not data from Jagex.
    private func checkExistingAuth() {
        if let tokenData = KeychainHelper.shared.read(key: "jagex_refresh_token"),
           let token = String(data: tokenData, encoding: .utf8), !token.isEmpty {
            self.isAuthenticated = true
            self.characterName = "Authenticated Jagex Account"
        }
    }

    /// Presentation context anchor for ASWebAuthenticationSession.
    /// Tells the operating system which UIWindow to present the authentication sheet over.
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Fall back to an empty UIWindow if no scene is connected yet; the sheet would then fail to present.
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }

    /// Initiate PKCE OAuth2 Login Session.
    ///
    /// - Parameter completion: Completion handler returning the token response or network error.
    public func startLogin(completion: @escaping (Result<JagexTokenResponse, Error>) -> Void) {
        // Step 1: Update UI loading state on the main dispatch queue
        DispatchQueue.main.async {
            self.isAuthenticating = true
            self.authError = nil
        }

        // PKCE (RFC 7636): the challenge sent to the server is SHA-256(verifier); only the app knows the verifier, so a stolen
        // authorization code is useless to an interceptor.
        // Step 2: Generate cryptographically secure PKCE Verifier & Challenge
        let codeVerifier = generateCodeVerifier()
        self.currentCodeVerifier = codeVerifier
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Step 3: Build Authorization URL query parameters
        var components = URLComponents(string: Self.authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Self.clientId),
            URLQueryItem(name: "redirect_uri", value: Self.redirectUri),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            // prompt=login forces the user to authenticate each time instead of reusing a silent session.
            URLQueryItem(name: "prompt", value: "login")
        ]

        guard let authURL = components.url else {
            completion(.failure(NSError(domain: "net.runelite.mobile", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid OAuth URL"])))
            return
        }

        // Step 4: Launch isolated ASWebAuthenticationSession
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "runelite-mobile"
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            DispatchQueue.main.async { self.isAuthenticating = false }

            // Both user cancel and network failure arrive as 'error'; the completion handler is always called exactly once per path.
            // Handle user cancelation or network error
            if let error = error {
                DispatchQueue.main.async { self.authError = error.localizedDescription }
                completion(.failure(error))
                return
            }

            // Extract the authorization code from the redirect URL query items
            guard let callbackURL = callbackURL,
                  let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                let err = NSError(domain: "net.runelite.mobile", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing authorization code"])
                DispatchQueue.main.async { self.authError = err.localizedDescription }
                completion(.failure(err))
                return
            }

            // Step 5: Exchange authorization code for tokens
            self.exchangeCodeForToken(code: code, codeVerifier: codeVerifier, completion: completion)
        }

        session.presentationContextProvider = self
        // false keeps the browser's cookies between logins (fewer password prompts) at the cost of sharing state with Safari.
        session.prefersEphemeralWebBrowserSession = false // Allows persistent cookie session for Jagex Account
        self.authSession = session
        session.start()
    }

    /// Exchange authorization code for OAuth2 tokens via HTTPS POST.
    ///
    /// - Parameters:
    ///   - code: The single-use authorization code returned by Jagex.
    ///   - codeVerifier: The PKCE verifier string matching the initial code_challenge.
    ///   - completion: Callback returning tokens or error.
    private func exchangeCodeForToken(
        code: String,
        codeVerifier: String,
        completion: @escaping (Result<JagexTokenResponse, Error>) -> Void
    ) {
        // Silently returns without calling completion if the URL is invalid; the constant URL makes that unreachable in practice.
        guard let tokenEndpoint = URL(string: Self.tokenURL) else { return }

        // Configure URLRequest for application/x-www-form-urlencoded POST
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParameters: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": Self.clientId,
            "code": code,
            "redirect_uri": Self.redirectUri,
            "code_verifier": codeVerifier
        ]

        // Manual form encoding: .urlQueryAllowed leaves characters such as '+' and '&' unescaped, which could corrupt values containing them.
        // Verifier, client id and the authorization code are normally URL-safe, so this works in practice.
        let postString = bodyParameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        request.httpBody = postString.data(using: .utf8)

        // Dispatch network request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async { self.authError = error.localizedDescription }
                completion(.failure(error))
                return
            }

            guard let data = data else {
                let err = NSError(domain: "net.runelite.mobile", code: -3, userInfo: [NSLocalizedDescriptionKey: "Empty token response"])
                DispatchQueue.main.async { self.authError = err.localizedDescription }
                completion(.failure(err))
                return
            }

            do {
                // Decode JSON token response
                // Foundation's API is decode(_:from:); the label 'data:' does not exist and was a compile error.
                let tokenResponse = try JSONDecoder().decode(JagexTokenResponse.self, from: data)

                // Securely store refresh token in iOS Keychain
                // Only the refresh token is persisted; access/game tokens stay in memory with the returned struct. The save result is ignored.
                if let refreshToken = tokenResponse.refreshToken,
                   let tokenBytes = refreshToken.data(using: .utf8) {
                    KeychainHelper.shared.save(key: "jagex_refresh_token", data: tokenBytes)
                }

                // Update published properties on main UI thread
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                    self.characterName = "Authenticated Jagex Account"
                    self.authError = nil
                }
                completion(.success(tokenResponse))
            } catch {
                DispatchQueue.main.async { self.authError = "Failed to parse token response: \(error.localizedDescription)" }
                completion(.failure(error))
            }
        }
        task.resume()
    }

    /// Sign out and clear stored tokens from Keychain.
    public func logout() {
        KeychainHelper.shared.delete(key: "jagex_refresh_token")
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.characterName = nil
        }
    }

    // MARK: - PKCE Cryptographic Helpers

    /// Generate 32 cryptographically secure random bytes converted to URL-safe Base64.
    // 32 random bytes -> 43 base64url characters, within the 43-128 range RFC 7636 requires.
    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        // Return code ignored; on failure the bytes stay zero, which would make the verifier predictable.
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Compute the SHA-256 hash of the code verifier formatted as URL-safe Base64.
    // S256 method: base64url(SHA-256(ASCII verifier)) without '=' padding.
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .ascii) else { return "" }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
