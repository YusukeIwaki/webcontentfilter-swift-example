---
name: ios-content-filter
description: Develop the iOS Web Content Filter sample with correct provider split, verdicts, and MDM profile keys.
---

# iOS Content Filter Development

Use this skill when working in this repository on the Swift Content Filter
sample: the host app, `NEFilterDataProvider` / `NEFilterControlProvider`
extensions, `.mobileconfig` profiles, or the iOS 26 URL Filter.

Normative details live in the repo docs — read them instead of guessing:

- `AGENTS.md` — architecture map, invariants, conventions, doc index
- `docs/architecture.md` — the 4-party design and data flows
- `docs/content-filter-api.md` — Swift API reference (verified against SDK headers)
- `docs/profile-reference.md` — mobileconfig keys for `FilterType = Plugin`
- `docs/deployment.md` — deployment routes, entitlements, Xcode setup
- `docs/url-filter-ios26.md` — iOS 26 URL Filter (separate mechanism)
- `docs/references.md` — primary sources (TN3134, SDK headers, MDM spec)

## Rules you must not violate

1. The filter is not a VPN or proxy. Never design a flow that relays user
   traffic through `ServerAddress` — that key is only a configuration value
   handed to the providers ("where is this product's backend?").
2. Keep the Data / Control split. The Data provider judges flows but must
   never do networking, IPC, or writes (shared App Group is read-only for
   it). The Control provider fetches rules over HTTPS but cannot see flow
   content (`request` / `response` are always nil there).
3. Rules flow one way: Control writes to the shared App Group, then calls
   `notifyRulesChanged()`; Data reloads in `handleRulesChanged()`.
4. HTTPS bodies are not readable. Socket flows expose endpoint / hostname /
   port / protocol and (via peek) still-encrypted bytes. Only WebKit flows
   expose URL / request / parentURL, and that is not MITM.
5. On iOS 18+, use `remoteFlowEndpoint` / `localFlowEndpoint`
   (`Network.NWEndpoint`). `remoteEndpoint` / `localEndpoint` are deprecated.
6. A Plugin profile requires both `PluginBundleID` (the filter app's ID, not
   the extension's) and `UserDefinedName`. At least one of `FilterBrowsers` /
   `FilterSockets` must be true or the filter sees nothing.
7. Device-wide filters run one at a time on iOS; enabling one via
   `NEFilterManager` disables others. MDM-delivered configs cannot be
   overwritten from the app.
8. Deployment route decides the test plan: supervised device + MDM (iOS 9+),
   Screen Time child path (iOS 15+), per-app via `ContentFilterUUID`
   (iOS 16+), URL Filter (iOS 26+). The Simulator cannot verify filtering.

## Workflow

1. State which component you are changing (host app, Data appex, Control
   appex, profile) and which deployment route it targets.
2. Check the matching doc above for exact method signatures, verdict types,
   and profile keys before writing code.
3. If a doc and an Apple primary source conflict, the primary source wins —
   and update the doc.
4. For anything URL Filter related, read `docs/url-filter-ios26.md` first;
   it is a separate API (`NEURLFilterControlProvider`, Bloom prefilter,
   PIR) and must not be mixed into classic provider code.
