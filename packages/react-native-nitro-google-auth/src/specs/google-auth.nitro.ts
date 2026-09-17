import type { HybridObject } from "react-native-nitro-modules";

export interface GoogleAuth extends HybridObject<{
  ios: "swift";
  android: "kotlin";
}> {
  configure(config: GoogleAuthConfig): void;
  signIn(): Promise<GoogleSignInResult>;
  signOut(): Promise<void>;
}

export interface GoogleAuthConfig {
  /**
   * iOS client ID for the Google Sign-In SDK.
   */
  iosClientId?: string;
  /**
   * Web client ID for the Google Sign-In SDK.
   */
  webClientId?: string;
}

export interface GoogleUserData {
  idToken: string;
  providerUserId: string;
  email?: string;
  name?: string;
  photoUrl?: string;
}

export interface GoogleSignInError {
  code: string;
  message: string;
  /** Native diagnostics for Android credential provider failures. */
  android?: GoogleSignInAndroidDiagnostics;
}

export interface GoogleSignInAndroidDiagnostics {
  playServicesStatus: number;
  playServicesVersion?: string;
  nativeExceptionType: string;
  nativeMessage?: string;
  nativeStackTrace: string;
}

export interface GoogleSignInResult {
  data?: GoogleUserData;
  error?: GoogleSignInError;
}
