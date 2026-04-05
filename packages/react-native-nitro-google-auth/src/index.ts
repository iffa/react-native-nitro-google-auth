import { NitroModules } from "react-native-nitro-modules";
import type { GoogleAuth as GoogleAuthSpec } from "./specs/google-auth.nitro";

export type {
  GoogleAuthConfig,
  GoogleUserData,
  GoogleSignInResult,
  GoogleSignInError,
} from "./specs/google-auth.nitro";

export const GoogleAuth =
  NitroModules.createHybridObject<GoogleAuthSpec>("GoogleAuth");
