#if canImport(ExpoModulesCore)
import ExpoModulesCore
import ObjectiveC

public class GoogleAuthAppDelegate: ExpoAppDelegateSubscriber {
  public func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    do {
      return try SignInURLForwarder.handle(url)
    } catch {
      NSLog("[react-native-nitro-google-auth] Failed to handle sign-in URL: %@", String(describing: error))
      return false
    }
  }
}

/// Calls `[[GIDSignIn sharedInstance] handleURL:]` on the GoogleSignIn linked into GoogleAuth.
/// Linking a second copy here would give it its own `sharedInstance`.
private enum SignInURLForwarder {
  struct Unavailable: Error, CustomStringConvertible {
    let description: String
  }

  private typealias SharedInstance = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>
  private typealias HandleURL = @convention(c) (AnyObject, Selector, NSURL) -> ObjCBool

  static func handle(_ url: URL) throws -> Bool {
    guard let signInClass = NSClassFromString("GIDSignIn") else {
      throw Unavailable(description: "GIDSignIn is not linked into the app")
    }
    let sharedSelector = NSSelectorFromString("sharedInstance")
    let handleSelector = NSSelectorFromString("handleURL:")
    guard let sharedMethod = class_getClassMethod(signInClass, sharedSelector),
          let handleMethod = class_getInstanceMethod(signInClass, handleSelector)
    else {
      throw Unavailable(description: "GIDSignIn does not respond to sharedInstance and handleURL:")
    }

    let sharedInstance = unsafeBitCast(method_getImplementation(sharedMethod), to: SharedInstance.self)
    let handleURL = unsafeBitCast(method_getImplementation(handleMethod), to: HandleURL.self)
    let signIn = sharedInstance(signInClass, sharedSelector).takeUnretainedValue()
    return handleURL(signIn, handleSelector, url as NSURL).boolValue
  }
}
#endif
