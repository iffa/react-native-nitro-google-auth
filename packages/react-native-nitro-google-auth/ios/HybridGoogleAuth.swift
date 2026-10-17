import Foundation
import GoogleSignIn
import NitroModules
import UIKit

private let gidSignInErrorDomain = "com.google.GIDSignIn"
private let gidSignInCanceledCode = -5

/// How long sign-in waits for an inactive scene to become active.
private let sceneActivationTimeoutNanoseconds: UInt64 = 5_000_000_000

class HybridGoogleAuth: HybridGoogleAuthSpec {
    private var authConfig: GoogleAuthConfig?

    func configure(config: GoogleAuthConfig) throws {
        authConfig = config
    }

    func signIn() throws -> Promise<GoogleSignInResult> {
        return Promise.async {
            do {
                let configuration = try self.resolveConfiguration()
                try Self.validateRequiredUrlScheme()
                guard let presentingViewController = await Self.getPresentingViewController() else {
                    return GoogleSignInResult(
                        data: nil,
                        error: GoogleSignInError(
                            code: "NO_ACTIVE_WINDOW",
                            message: "No active window to present Google sign-in from.",
                            android: nil
                        )
                    )
                }
                let signInResult = try await self.performSignIn(
                    configuration: configuration,
                    presentingViewController: presentingViewController
                )

                let user = try await signInResult.user.refreshTokensIfNeeded()
                guard let idToken = user.idToken?.tokenString, !idToken.isEmpty else {
                    throw GoogleAuthError.missingIdToken
                }

                let profile = user.profile
                let profilePhotoUrl: String?
                if let profile, profile.hasImage {
                    profilePhotoUrl = profile.imageURL(withDimension: 256)?.absoluteString
                } else {
                    profilePhotoUrl = nil
                }

                let providerUserId = user.userID ?? profile?.email
                guard let providerUserId, !providerUserId.isEmpty else {
                    throw GoogleAuthError.missingProviderUserId
                }

                let userData = GoogleUserData(
                    idToken: idToken,
                    providerUserId: providerUserId,
                    email: profile?.email,
                    name: profile?.name,
                    photoUrl: profilePhotoUrl
                )
                return GoogleSignInResult(data: userData, error: nil)
            } catch {
                if Self.isSignInCancelled(error) {
                    return GoogleSignInResult(
                        data: nil,
                        error: GoogleSignInError(
                            code: "CANCELLED",
                            message: "The user canceled the sign-in flow.",
                            android: nil
                        )
                    )
                }
                throw error
            }
        }
    }

    private static func isSignInCancelled(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == gidSignInErrorDomain && ns.code == gidSignInCanceledCode
    }

    func signOut() throws -> Promise<Void> {
        return Promise.async {
            await MainActor.run {
                GIDSignIn.sharedInstance.signOut()
            }
        }
    }

    @MainActor
    private func performSignIn(
        configuration: GIDConfiguration,
        presentingViewController: UIViewController
    ) async throws -> GIDSignInResult {
        GIDSignIn.sharedInstance.configuration = configuration
        return try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
    }

    private func resolveConfiguration() throws -> GIDConfiguration {
        let iosClientId = authConfig?.iosClientId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let webClientId = authConfig?.webClientId?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let iosClientId, !iosClientId.isEmpty else {
            throw GoogleAuthError.missingIosClientId
        }
        guard let webClientId, !webClientId.isEmpty else {
            throw GoogleAuthError.missingWebClientId
        }

        return GIDConfiguration(clientID: iosClientId, serverClientID: webClientId)
    }

    private static func validateRequiredUrlScheme() throws {
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        let schemes = urlTypes?.flatMap { urlType -> [String] in
            (urlType["CFBundleURLSchemes"] as? [String]) ?? []
        } ?? []
        let hasGoogleScheme = schemes.contains { scheme in
            scheme.lowercased().hasPrefix("com.googleusercontent.apps")
        }
        guard hasGoogleScheme else {
            throw GoogleAuthError.missingUrlScheme
        }
    }

    /// Google's sheet needs an active scene. A scene goes inactive while the
    /// app is still on screen, for example under Control Center, a system
    /// prompt or a half-finished app switcher gesture. A tap can land in that
    /// state, so sign-in waits for the scene to become active again.
    @MainActor
    private static func getPresentingViewController() async -> UIViewController? {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        if let windowScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) {
            return keyRootViewController(in: windowScene).map(topMostViewController(from:))
        }

        guard
            let windowScene = windowScenes.first(where: { $0.activationState == .foregroundInactive }),
            await waitForActivation(of: windowScene)
        else {
            return nil
        }

        return keyRootViewController(in: windowScene).map(topMostViewController(from:))
    }

    @MainActor
    private static func keyRootViewController(in windowScene: UIWindowScene) -> UIViewController? {
        windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
    }

    /// Resolves true when the scene becomes active, false on timeout.
    @MainActor
    private static func waitForActivation(of scene: UIScene) async -> Bool {
        let activations = NotificationCenter.default.notifications(
            named: UIScene.didActivateNotification,
            object: scene
        )

        // Subscribed above, so an activation between here and the loop is not lost
        if scene.activationState == .foregroundActive {
            return true
        }

        return await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in activations {
                    return true
                }
                return false
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: sceneActivationTimeoutNanoseconds)
                return false
            }

            let activated = await group.next() ?? false
            group.cancelAll()
            return activated
        }
    }

    @MainActor
    private static func topMostViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topMostViewController(from: presented)
        }
        if let navigationController = root as? UINavigationController,
           let visible = navigationController.visibleViewController {
            return topMostViewController(from: visible)
        }
        if let tabBarController = root as? UITabBarController,
           let selected = tabBarController.selectedViewController {
            return topMostViewController(from: selected)
        }
        return root
    }
}

/// Nitro passes a thrown error to JS as `String(describing:)`, which is the
/// case name unless the error describes itself.
private enum GoogleAuthError: LocalizedError, CustomStringConvertible {
    case missingIdToken
    case missingProviderUserId
    case missingIosClientId
    case missingWebClientId
    case missingUrlScheme

    var description: String {
        errorDescription ?? String(reflecting: self)
    }

    var errorDescription: String? {
        switch self {
        case .missingIdToken:
            return "Google sign-in did not return an idToken."
        case .missingProviderUserId:
            return "Google sign-in did not return a provider user identifier."
        case .missingIosClientId:
            return "Set iosClientId via GoogleAuth.configure(...) before calling signIn()."
        case .missingWebClientId:
            return "Set webClientId via GoogleAuth.configure(...) before calling signIn()."
        case .missingUrlScheme:
            return "Add a URL scheme starting with \"com.googleusercontent.apps\" in Info.plist CFBundleURLTypes for Google Sign-In."
        }
    }
}
