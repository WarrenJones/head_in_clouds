export function appleAppSiteAssociation({
  appIDPrefix = process.env.APPLE_APP_ID_PREFIX ?? "TEAMID",
  bundleID = process.env.IOS_BUNDLE_ID ?? process.env.APNS_BUNDLE_ID ?? "com.headintheclouds.app",
  paths = process.env.IOS_ASSOCIATED_DOMAIN_PATHS
} = {}) {
  const appID = `${appIDPrefix}.${bundleID}`;
  return {
    applinks: {
      apps: [],
      details: [
        {
          appID,
          paths: parsePaths(paths)
        }
      ]
    }
  };
}

function parsePaths(paths) {
  if (!paths) {
    return [
      "/share/*",
      "/wechat/*",
      "/flight-spaces/*",
      "/cards/*"
    ];
  }
  return paths
    .split(",")
    .map((path) => path.trim())
    .filter(Boolean);
}
