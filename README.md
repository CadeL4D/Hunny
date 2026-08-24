# 🍯 Hunny

[![Build](https://github.com/CadeL4D/Hunny/actions/workflows/build.yml/badge.svg)](https://github.com/CadeL4D/Hunny/actions/workflows/build.yml)

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
   create the collections, role, and the two player users on your instance.
2. **Install the app** — grab the latest unsigned IPA from
   [Releases](https://github.com/CadeL4D/Hunny/releases) and sideload it with
   [AltStore](https://altstore.io), [SideStore](https://sidestore.io) or
   Sideloadly. Free Apple IDs re-sign the app for 7 days at a time; TrollStore users
   can install the fakesigned IPA directly.
3. **Open the app** — enter your Directus URL, the static token for your user, and a
   display name. Do the same on the second device with the *other* user's token.

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
git tag v0.1.0
git push origin v0.1.0
```

The workflow archives with code signing disabled, fakesigns with `ldid`, and packs
`Payload/Hunny.app` into `Hunny.ipa` — no Apple Developer account or certificates
anywhere in the pipeline.

## Project structure

```
Hunny/
├── Hunny/                  # App source (SwiftUI)
│   ├── Directus/           # REST client + keychain
│   ├── State/              # AppState: sync, scoring, actions
│   ├── Support/            # Week math, ISO dates, haptics
│   ├── Views/              # Tasks, Compete, Question, setup, components
│   └── Models.swift        # Codable models mirroring the Directus schema
├── docs/DIRECTUS_SETUP.md  # Everything to create on your Directus instance
├── project.yml             # XcodeGen project definition
└── .github/workflows/      # Unsigned IPA build + release workflow
```

## How scoring works

- Every completed personal task is **+1 point** for that week (a 4× task earns up
  to 4 points, max one per day).
- The weekly head-to-head is **+1 point** to whoever claims it first — the database
  enforces this with a unique constraint, so it's race-proof even if both devices
  tap at the same moment.
- Weeks run Monday → Sunday and roll over automatically once the new week's content
  is added in Directus.

## License

[MIT](LICENSE)
