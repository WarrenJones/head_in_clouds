# Dev Context: Head in the Clouds

## Stage 1 Platform Gate

Stage 1 primary deliverable is an iOS app using SwiftUI / VisionKit.

Do not replace Stage 1 with Web/PWA because it is easier to scaffold, test, or deploy in the current repository. If the current environment cannot build or verify the iOS app, stop and report the blocker instead of silently downgrading the product surface.

Web/PWA is allowed only for:
- `16 Shared Card Landing`
- marketing or public preview pages
- testing fallback / interactive mock support

Android and HarmonyOS remain future platform targets. Do not make product or data-model decisions that unnecessarily lock the product to iOS-only behavior.

Before writing code or scaffolding files, dev must state:

```text
Primary platform: iOS app (SwiftUI / VisionKit)
Auxiliary surfaces: Web/PWA only for shared landing, marketing, or test fallback
Future targets: Android and HarmonyOS remain open
```

## Design Source Gate

Latest verified design source:

- Figma Make file: `https://www.figma.com/make/AtPRtpoJCOkAhhDBkIuKak/%E4%BA%91%E4%B8%8A%E5%BF%83%E4%BA%8B%E8%AE%BE%E8%AE%A1?fullscreen=1&t=a6TeM9rcjjoYuSLn-1&code-node-id=0-9`
- File key: `AtPRtpoJCOkAhhDBkIuKak`
- Root node used for Figma MCP context: `0:9`
- Retrieved via Figma MCP on 2026-05-20.

Do not ask the founder to manually export Figma resources if the browser session or Figma MCP can access the file. Use this source first, then fall back to screenshots only if MCP access fails.

## Third-Party Dependency Gate

`head_in_clouds/THIRD_PARTY.md` is required before production integration work.

Dev may build app UI, domain logic, and adapter-backed mocks while Apple, WeChat, SMS, China backend cloud, event pipeline, APNs, IAP, Sentry, and domain configuration are pending. Dev must not claim production completion or set manifest verification flags to true until real provider evidence is captured.

## China Production Infrastructure Gate

The target launch market is China. Production architecture must not depend on direct client access to Supabase Cloud or PostHog Cloud.

Production direction:

- App data path: iOS app -> first-party China-accessible API -> China-region database/object storage.
- Analytics path: iOS app -> first-party `/events` API -> China-region event store/dashboard -> optional async relay to domestic analytics or PostHog.
- Notifications: local iOS notifications for boarding reminders; APNs only for server-originated same-flight/new-note notifications.
- Supabase Cloud: allowed only for overseas/dev staging or schema reference, not China production.
- PostHog Cloud: allowed only as optional internal downstream after server-side relay, not direct iOS SDK ingestion for China production.

Do not add production SDKs or environment variables that make the iOS app depend on direct Supabase/PostHog reachability from China networks.
