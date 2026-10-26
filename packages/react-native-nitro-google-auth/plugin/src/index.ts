import type { ExpoConfig } from "@expo/config-types";
import {
  type ConfigPlugin,
  type ExportedConfigWithProps,
  type InfoPlist,
  IOSConfig,
  createRunOncePlugin,
  withInfoPlist,
  withPodfile,
} from "@expo/config-plugins";
import {
  mergeContents,
  removeContents,
} from "@expo/config-plugins/build/utils/generateCode";

const pkg = require("react-native-nitro-google-auth/package.json");

export type GoogleAuthConfigPluginOptions = {
  /** Reversed iOS client ID URL scheme, e.g. com.googleusercontent.apps.xxx */
  iosUrlScheme: string;
  /**
   * Resolve GoogleSignIn through Swift Package Manager instead of CocoaPods.
   * Use it with React Native Firebase 27+ and `useFrameworks: "dynamic"`.
   * Writes `$GoogleAuthUseSPM = true` to the Podfile.
   */
  iosUseSwiftPackageManager?: boolean;
};

const PODFILE_TAG = "react-native-nitro-google-auth-spm";

export function setPodfileUseSPM(src: string, enabled: boolean): string {
  if (!enabled) {
    return removeContents({ src, tag: PODFILE_TAG }).contents;
  }
  return mergeContents({
    src,
    newSrc: "$GoogleAuthUseSPM = true",
    tag: PODFILE_TAG,
    anchor: /^platform :ios/m,
    offset: 1,
    comment: "#",
  }).contents;
}

const withGoogleAuthPodfile: ConfigPlugin<boolean> = (config, enabled) =>
  withPodfile(config, (cfg) => {
    cfg.modResults.contents = setPodfileUseSPM(
      cfg.modResults.contents,
      enabled
    );
    return cfg;
  });

const withGoogleAuth: ConfigPlugin<GoogleAuthConfigPluginOptions | void> = (
  config: ExpoConfig,
  options
) => {
  const iosUrlScheme = options?.iosUrlScheme?.trim();

  config = withGoogleAuthPodfile(
    config,
    options?.iosUseSwiftPackageManager === true
  );

  return withInfoPlist(config, (cfg: ExportedConfigWithProps<InfoPlist>) => {
    if (!iosUrlScheme) {
      return cfg;
    }

    if (!IOSConfig.Scheme.hasScheme(iosUrlScheme, cfg.modResults)) {
      cfg.modResults = IOSConfig.Scheme.appendScheme(
        iosUrlScheme,
        cfg.modResults
      );
    }
    return cfg;
  });
};

export default createRunOncePlugin<GoogleAuthConfigPluginOptions | void>(
  withGoogleAuth,
  pkg.name,
  pkg.version
);
