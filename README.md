# Create — iOS

Native SwiftUI client for **Create**, a mobile-first AI image and video generation studio built on
the kie.ai model APIs. Write a prompt, attach reference images or dictate it, pick a model, generate,
then browse, share and export the results.

This is the iOS port of an existing web app; it reuses the same backend (Next.js API routes over a
PocketBase instance), so the native client is a pure front end over a documented HTTP contract
(`CONTRACTS.md`).

## Architecture

- **Two surfaces** — *Create*, a chat-like composer (prompt, voice dictation, reference thumbnails,
  model sheet, settings sheet) with an inverted feed of recent generations underneath; and *Gallery*,
  a two-column grid with pull-to-refresh and a full-screen lightbox offering native share, one-click
  upscale and cutout, download and delete.
- **Asynchronous generation flow** — a generation is created server-side, then tracked by polling
  while a server callback finalises it; the client renders pending, done and failed states and
  refreshes the feed when a push notification arrives.
- **Data-driven model catalogue** (`Sources/Models/ModelCatalog.swift`, `CatalogLogic.swift`) — the
  set of available models and their per-model parameters is described as data rather than hardcoded
  screens, so adding a model does not mean adding UI.
- **Networking layer** (`Sources/Networking/`) — typed endpoints, DTOs, a shared `APIClient` and
  PocketBase authentication, with the token held in the Keychain (`State/KeychainStore.swift`).
- **Services** — audio recorder for dictation, image uploader, media saver to the photo library,
  push registration, share sheet, video thumbnail playback.
- **Design layer** (`Sources/Design/`) — a "liquid glass" look: aurora background, glass surfaces,
  specular borders, shimmer placeholders, iridescent button style, motion and haptics tokens.
- **CI and store tooling** — XcodeGen project generation plus three GitHub Actions workflows
  (release, App Store metadata, simulator screenshots) with Fastlane lanes.

## Stack

Swift, SwiftUI, XcodeGen, Fastlane (match, TestFlight, deliver), GitHub Actions. Backend:
Next.js API routes and PocketBase, kie.ai for generation.

## Build

```bash
brew install xcodegen
xcodegen generate
open Create.xcodeproj
```

The app points at a hosted backend and requires an account on it; signup is closed, so a clean clone
builds and runs but cannot log in. Release lanes need signing and App Store Connect secrets.

## Status

Not published. Feature-complete against the specification, never submitted to the App Store.

## Licence

No licence granted. Published for reading.
