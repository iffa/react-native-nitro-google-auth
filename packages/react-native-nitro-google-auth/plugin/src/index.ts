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

const MESSAGE_PREFIX = "react-native-nitro-google-auth";

function validateOptions(
  options: GoogleAuthConfigPluginOptions | void,
): GoogleAuthConfigPluginOptions {
  const iosUrlScheme = options?.iosUrlScheme?.trim();
  if (!iosUrlScheme) {
    throw new Error(
      `${MESSAGE_PREFIX}: Missing \`iosUrlScheme\` in plugin options: ${JSON.stringify(options)}`,
    );
  }

  if (typeof iosUrlScheme !== "string") {
    throw new Error(
      `${MESSAGE_PREFIX}: \`iosUrlScheme\` must be a string: ${iosUrlScheme}`,
    );
  }

  if (!iosUrlScheme.startsWith("com.googleusercontent.apps.")) {
    throw new Error(
      `${MESSAGE_PREFIX}: \`iosUrlScheme\` must start with "com.googleusercontent.apps.": ${iosUrlScheme}`,
    );
  }

  return { iosUrlScheme };
}

const withGoogleAuth: ConfigPlugin<GoogleAuthConfigPluginOptions | void> = (
  config: ExpoConfig,
  options,
) => {
  const { iosUrlScheme } = validateOptions(options);

  return withInfoPlist(config, (cfg: ExportedConfigWithProps<InfoPlist>) => {
    if (!IOSConfig.Scheme.hasScheme(iosUrlScheme, cfg.modResults)) {
      cfg.modResults = IOSConfig.Scheme.appendScheme(
        iosUrlScheme,
        cfg.modResults,
      );
    }
    return cfg;
  });
};

export default createRunOncePlugin<GoogleAuthConfigPluginOptions | void>(
  withGoogleAuth,
  pkg.name,
  pkg.version,
);
