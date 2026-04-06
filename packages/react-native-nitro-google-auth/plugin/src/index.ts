import type { ExpoConfig } from "@expo/config-types";
import {
  type ConfigPlugin,
  type ExportedConfigWithProps,
  type InfoPlist,
  IOSConfig,
  createRunOncePlugin,
  withInfoPlist,
} from "@expo/config-plugins";

const pkg = require("react-native-nitro-google-auth/package.json");

export type GoogleAuthConfigPluginOptions = {
  /** Reversed iOS client ID URL scheme, e.g. com.googleusercontent.apps.xxx */
  iosUrlScheme: string;
};

const withGoogleAuth: ConfigPlugin<GoogleAuthConfigPluginOptions | void> = (
  config: ExpoConfig,
  options
) => {
  const iosUrlScheme = options?.iosUrlScheme?.trim();

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
