//
//  JagexOAuthManager.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import Foundation
import AuthenticationServices
import CommonCrypto

/// Jagex OAuth2 Token response structure
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

/// Zero-Credential Jagex Account OAuth2 PKCE Authentication Engine
public final class JagexOAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    public static let shared = JagexOAuthManager()

    // Official Jagex Identity Provider Endpoints
    public static let authorizeURL = "https://account.jagex.com/oauth2/auth"
    public static let tokenURL = "https://account.jagex.com/oauth2/token"
    public static let clientId = "oldschool-runescape-mobile-ios"
    public static let redirectUri = "runelite-mobile://oauth-callback"
    public static let scopes = "openid offline gametoken"

    @Published public var isAuthenticated: Bool = false
    @Published public var characterName: String? = nil
    @Published public var isAuthenticating: Bool = false
    @Published public var authError: String? = nil

    private var currentCodeVerifier: String?
    private var authSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        checkExistingAuth()
    }

    /// Check if a valid refresh token exists in the Keychain
    private func checkExistingAuth() {
        if let tokenData = KeychainHelper.shared.read(key: "jagex_refresh_token"),
           let token = String(data: tokenData, encoding: .utf8), !token.isEmpty {
            self.isAuthenticated = true
            self.characterName = "Authenticated Jagex Account"
        }
    }

    /// Presentation context anchor for ASWebAuthenticationSession
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }

    /// Initiate PKCE OAuth2 Login Session
    public func startLogin(completion: @escaping (Result<JagexTokenResponse, Error>) -> Void) {
        DispatchQueue.main.async {
            self.isAuthenticating = true
            self.authError = nil
        }

        // 1. Generate cryptographically secure PKCE Verifier & Challenge
        let codeVerifier = generateCodeVerifier()
        self.currentCodeVerifier = codeVerifier
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // 2. Build Authorization URL query parameters
        var components = URLComponents(string: Self.authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Self.clientId),
            URLQueryItem(name: "redirect_uri", value: Self.redirectUri),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "login")
        ]

        guard let authURL = components.url else {
            completion(.failure(NSError(domain: "net.runelite.mobile", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid OAuth URL"])))
            return
        }

        // 3. Launch isolated ASWebAuthenticationSession
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "runelite-mobile"
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            DispatchQueue.main.async { self.isAuthenticating = false }

            if let error = error {
                DispatchQueue.main.async { self.authError = error.localizedDescription }
                completion(.failure(error))
                return
            }

            guard let callbackURL = callbackURL,
                  let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                let err = NSError(domain: "net.runelite.mobile", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing authorization code"])
                DispatchQueue.main.async { self.authError = err.localizedDescription }
                completion(.failure(err))
                return
            }

            // 4. Exchange authorization code for tokens
            self.exchangeCodeForToken(code: code, codeVerifier: codeVerifier, completion: completion)
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false // Allows persistent cookie session for Jagex Account
        self.authSession = session
        session.start()
    }

    /// Exchange authorization code for OAuth2 tokens via HTTPS POST
    private func exchangeCodeForToken(
        code: String,
        codeVerifier: String,
        completion: @escaping (Result<JagexTokenResponse, Error>) -> Void
    ) {
        guard let tokenEndpoint = URL(string: Self.tokenURL) else { return }

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

        let postString = bodyParameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        request.httpBody = postString.data(using: .utf8)

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
                let tokenResponse = try JSONDecoder().decode(JagexTokenResponse.self, data: data)

                // Securely store refresh token in iOS Keychain
                if let refreshToken = tokenResponse.refreshToken,
                   let tokenBytes = refreshToken.data(using: .utf8) {
                    KeychainHelper.shared.save(key: "jagex_refresh_token", data: tokenBytes)
                }

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

    /// Sign out and clear stored tokens from Keychain
    public func logout() {
        KeychainHelper.shared.delete(key: "jagex_refresh_token")
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.characterName = nil
        }
    }

    // MARK: - PKCE Cryptographic Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

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
