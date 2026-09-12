# tldr

A private, calm feed of short news briefings.
Cross-platform (Android + PWA), built with Flutter. Bilingual English + Hebrew with true RTL. No account, no streaks, no ads, no notifications. Everything stays on the device.

Distributed through [AppSync](https://github.com/unix14/appSync).

---

## Product principles

1. Useful by default. Every card carries clear informational or discovery value.
2. Trust before speed. Every factual card has a Sources button.
3. Private by design. Interests, saves, and history stay on the device.
4. No social pressure. No likes, follows, comments, or public profiles.
5. Depth is optional. Cards stay lightweight; users can inspect sources or open the original video/article.
6. Calm, not boring. Editorial serif type, true-black OLED theme, no rage bait.
7. Transparent uncertainty. Confirmed / Developing / Disputed / Analysis states are labeled.

## Stack

- **Flutter** (stable channel) — single codebase for Android + Web PWA.
- **Riverpod** for state.
- **shared_preferences** for local storage. No backend, no accounts.
- **youtube_player_iframe** for optional Go Deeper video playback.
- **Google Fonts** — Fraunces (serif) for headlines + Inter for body.

## Layout

```
lib/
├── app/               MaterialApp + scroll behavior
├── theme/             Colors, typography, ThemeData
├── models/            ContentCard, SourceRef, Interest
├── data/              Repositories + Riverpod providers
├── widgets/           Reusable atoms (TopicChip, PublisherFavicon, …)
└── features/
    ├── onboarding/    First-launch language + interests
    ├── feed/          Vertical PageView + ranker + cards
    ├── library/       Saved-item store
    ├── settings/      Preferences + privacy panel
    └── shell/         Bottom-nav shell
assets/
└── content/
    └── cards.json     Mock feed (v1 uses hand-crafted cards; live pipeline is future work)
web/                   PWA manifest, splash, icons
android/               Debug build target
.github/workflows/     CI + AppSync release
```

## Local development

```bash
flutter pub get
flutter run -d chrome         # PWA in your browser
flutter run -d <android-id>   # Android device or emulator
```

Analyze:

```bash
flutter analyze
```

Build outputs:

```bash
flutter build web --release
flutter build apk --debug
```

## Release + distribution (AppSync)

Every user-visible change gets its own semver tag:

```bash
git tag v0.1.0 -m "First public build"
git push origin v0.1.0
```

The tag triggers `.github/workflows/release.yml`:

1. Builds a debug APK, renames to `app-release.apk`.
2. Publishes a GitHub Release with the APK attached.
3. Updates `app-manifest.json` on the default branch (`latest_version`, `apk_asset_name`, `release_notes`).
4. If the AppSync Hub webhook secrets are set, notifies the Hub.

**Debug vs release signing.** For now the release pipeline ships a *debug*-signed APK — every Android device installs it via sideload, but the OS labels the build as debug. Switch to release signing once a keystore is added to repo secrets and `signingConfigs` in `android/app/build.gradle`; the workflow change is a one-liner (`--debug` → `--release`).

### AppSync Hub wiring (optional)

To have the AppSync Hub broadcast updates the moment a tag lands, set these in **Settings → Secrets and variables → Actions**:

| Kind | Name | Value |
|------|------|-------|
| Secret | `APPSYNC_WEBHOOK_SECRET` | Same string set as the Hub's `WEBHOOK_SECRET` |
| Secret | `TS_AUTHKEY` | Tailscale ephemeral auth key |
| Variable | `APPSYNC_HUB_URL` | Hub tailnet URL, e.g. `http://appsync-hub:8080` (no trailing slash) |

Absent secrets → the workflow logs `::notice::Hub webhook skipped` and finishes green.

### Central source registration

`tldr` is registered under `unix14/appsync_eyalya_source` in the `apps` group. Add / remove there to control whether the app appears in AppSync clients pointed at that source.

## Design origin

- [PRD.pdf](PRD.pdf) — v0.1 product requirements.
- [chat_history.md](chat_history.md) — early exploration and adversarial review.
