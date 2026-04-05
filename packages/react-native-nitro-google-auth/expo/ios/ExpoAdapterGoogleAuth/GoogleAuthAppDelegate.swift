#if canImport(ExpoModulesCore)
import ExpoModulesCore
import GoogleSignIn

public class GoogleAuthAppDelegate: ExpoAppDelegateSubscriber {
  private func handleSignInURL(_ url: URL) throws -> Bool {
    return GIDSignIn.sharedInstance.handle(url)
  }

  public func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    do {
      return try handleSignInURL(url)
    } catch {
      NSLog("[react-native-nitro-google-auth] Failed to handle sign-in URL: %@", String(describing: error))
      return false
    }
  }
}
#endif
