# 🍯 Hunny

[![Build](https://github.com/CadeL4D/Hunny/actions/workflows/build.yml/badge.svg)](https://github.com/CadeL4D/Hunny/actions/workflows/build.yml)
[![Pages](https://github.com/CadeL4D/Hunny/actions/workflows/pages.yml/badge.svg)](https://github.com/CadeL4D/Hunny/actions/workflows/pages.yml)

Hunny is a small, polished iOS app for two people who share a week together. It syncs
through your own [Directus](https://directus.io) instance and keeps score across three
weekly games:

- **Tasks** — your personal checklist. Finish a task, score a point for the week.
  Some tasks can be done up to four times a week, but only once per day.
- **Compete** — one head-to-head task a week. The first device to claim it wins the
  point, and it shows as completed by them.
- **Question** — a question of the week. Each device writes its answer; you can only
  see the other person's answer once they've written one. If they're lagging, send
  them a nudge that shows up right in the app.

Built with Swift and SwiftUI, designed to feel at home next to Apple's own apps.

## Getting started

1. **Set up Directus** — follow [`docs/DIRECTUS_SETUP.md`](docs/DIRECTUS_SETUP.md) to
   create the collections, the app role, and the service token on your instance.
2. **Install the app** — grab the latest unsigned IPA from
   [Releases](https://github.com/CadeL4D/Hunny/releases) and sideload it with
   [AltStore](https://altstore.io), [SideStore](https://sidestore.io) or
   Sideloadly. Free Apple IDs re-sign the app for 7 days at a time; TrollStore users
   can install the fakesigned IPA directly.
3. **Open the app** — type your name and your partner's name. Do the same on the
   second device. The names must match across devices exactly — capitals count —
   and that's the entire login.

## Building

The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen), so
the `.xcodeproj` is never committed.

**Locally** (requires Xcode):

```bash
brew install xcodegen
xcodegen generate
open Hunny.xcodeproj
```

**On GitHub Actions** — every push to `main` builds an unsigned IPA and attaches it
as a build artifact. Push a tag to publish a Release:

```bash
git tag v0.2.0
git push origin v0.2.0
```

The workflow expects two repository secrets: `DIRECTUS_URL` (your Directus base
URL) and `DIRECTUS_TOKEN` (the app's service token). Both are injected into the
binary (base64-encoded) at build time and never appear in the repo or its
history.

The workflow archives with code signing disabled, fakesigns with `ldid`, and packs
`Payload/Hunny.app` into `Hunny.ipa` — no Apple Developer account or certificates
anywhere in the pipeline.

## Web version (GitHub Pages)

`web/` is a dependency-free HTML/CSS/JS port of the SwiftUI app — same screens,
same Directus collections, same scoring, and the same hidden task editor (five
taps on your profile avatar). Every push to `main` that touches `web/` deploys it
to GitHub Pages via [`.github/workflows/pages.yml`](.github/workflows/pages.yml),
which injects the server URL and token from the same `DIRECTUS_URL` /
`DIRECTUS_TOKEN` secrets at deploy time (the committed `web/config.js` stays
empty, so neither value ever appears in the repo).

To run it locally, copy the folder out of the repo, fill in a real `config.js`
and serve it — the API allows cross-origin requests:

```bash
cp -r web /tmp/hunny-web
$EDITOR /tmp/hunny-web/config.js   # baseURL + token
cd /tmp/hunny-web && python3 -m http.server
```

Known differences from the iOS app: SF Symbols render as emoji (a curated set)
or SVGs, haptics become vibration where the browser supports it, and pull-to-
refresh is touch-only (desktop gets the 20-second polling).

## Project structure

```
Hunny/
├── Hunny/                  # App source (SwiftUI)
│   ├── Directus/           # REST client
│   ├── State/              # AppState: sync, scoring, actions
│   ├── Support/            # Week math, ISO dates, haptics
│   ├── Views/              # Tasks, Compete, Question, setup, components
│   └── Models.swift        # Codable models mirroring the Directus schema
├── web/                    # HTML/JS port, deployed to GitHub Pages
├── docs/DIRECTUS_SETUP.md  # Everything to create on your Directus instance
├── project.yml             # XcodeGen project definition
└── .github/workflows/      # Unsigned IPA build + Pages deploy workflows
```

## How scoring works

- Every completed personal task is **+1 point** for that week (a 4× task earns up
  to 4 points, max one per day).
- The weekly head-to-head is **+1 point** to whoever claims it first — the database
  enforces this with a unique constraint, so it's race-proof even if both devices
  tap at the same moment.
- Weeks run Monday → Sunday and roll over automatically once the new week's content
  is added in Directus.
- The score header also tracks a **monthly total**: every point both players earn
  from the 1st until the end of the month, resetting on the 1st.

## License

[MIT](LICENSE)
