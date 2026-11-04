# Current work

## Coming Soon hero on the native apps

Client repo: **silo-apple** (iOS, iPadOS, tvOS, macOS). `silo-android` is not
checked out on this machine, so Apple only. Branch: `Development`.

Contract and root cause: `docs/integration/coming-soon-hero.md`.

### What changed

A Home row the server flags `featured` now renders as a hero carousel at the top
of Home on iOS/iPadOS and tvOS, and no longer also renders as a poster row. A
curated "Most Anticipated" slide the library does not own opens its title page
instead of the catalog item detail, so it can never end in "not found". macOS
already had a featured hero; it now routes and gates its Play button the same
way.

- **Models** — `iosApp/iosApp/Networking/Models.swift`: `SectionItem` gains
  additive optional `availability`, `tmdbId`, `releaseDate`, `heroVideoUrl`,
  plus `isComingSoon`, `comingSoonTmdbId`, `comingSoonMediaType`.
- **Routing** — `iosApp/iosApp/Navigation/Route.swift`: `Route.card(...)` sends
  a coming-soon card to `.requestDetail` (the title page the web uses), every
  other card to `.itemDetail`.
- **Home** — `iosApp/iosApp/Screens/Home/HomeView.swift`: the first featured
  section is lifted to the top; iOS renders `PhoneHomeHero`, tvOS renders
  `TVFeaturedHero` over the Skyline feed; taps go through `Route.card`.
- **New iOS/iPadOS hero** — `Screens/Home/Hero/PhoneHomeHero.swift`, with
  `HomeHeroContent.swift` (formatting), `HeroTitleLogo.swift`,
  `HeroTrailerPlayer.swift` (AVFoundation clip host). Styled to Prime Video's
  mobile hero: bleeds under the status bar, ~90% of the page height so only the
  next row peeks, Prime's metadata track (year · runtime · 2 genres · cert, no
  rating), a three-line synopsis whose last line fades, borderless translucent
  pills, larger page dots, and a mute control only while the clip is running.
  The height is measured from the page (`GeometryReader` in `HomeView`) rather
  than `containerRelativeFrame`, so it is deterministic and renderable.
- **New tvOS hero** — `tvOS/Components/TVFeaturedHero.swift` (single composite
  focus owner: Left/Right page, Select opens the page, Play/Pause toggles the
  clip, Up → menu, Down → rows).
- **Theme** — `WeFlixTheme.Skyline.heroHeightFraction`.
- **macOS** — `macOS/MacFeaturedHero.swift`: Play gated on `!isComingSoon`,
  More Info routes through `.card`.

### Verification

| # | Check | Result |
| --- | --- | --- |
| 1 | iOS build (scheme WeFlix, iPhone 17 / iOS 27 sim) | pass |
| 2 | tvOS build (scheme WeFlixTV, Apple TV 4K / tvOS 27 sim) | pass |
| 3 | macOS build (scheme WeFlixMac) | Swift sources compile (82 compile jobs); the build then fails at `CompileAssetCatalogVariant` — a local `actool`/`ibtoold` plug-in load failure ("A required plugin failed to load", also "CoreSimulator is out of date"), unrelated to this change |
| 4 | New warnings vs baseline | none introduced (2 iOS, 3 tvOS are pre-existing) |
| 5 | Existing tests (`WeFlixTests`, iPhone 17 / iOS 27 sim) | 3659 tests, 6 failures — all pre-existing and independent of the change: `CalendarTimeZoneTests` is date-dependent (its assertion only holds in some weeks) and two `SubtitleDisplayScopeTests` are about subtitle-appearance stores. None reference the changed code |
| 6 | Hero shows admin order, dots/counter | not verified (no live server) |
| 7 | Trailer autoplay / mute / backdrop-only | not verified (no live server) |
| 8 | Coming-soon details opens (no "not found") | not verified (no live server) |
| 9 | In-library title shows Play and plays | not verified (no live server) |
| 10 | Flag off → no hero, no broken row | not verified (no live server) |
| 11 | Other rows/library/playback unchanged | by construction (unchanged code paths) |
| 12 | TV D-pad through hero and rows | not verified (no live server / no device) |
| 13 | silo-server `git status` unchanged | pass |
| 14 | Rendered iOS hero (scratch `ImageRenderer` test at 393×852, since removed) | pass — matches the Prime reference: eyebrow, title, "2026 · 1h 57m · Mystery · Thriller · R", faded 3-line synopsis, Play + More Info pills (coming-soon variant shows badge + More Info only), 5 page dots, next row peeking |

Builds are compile-only evidence on simulators with no server configured; the
behavioural checks need a running silo-server and a curated Most Anticipated
list.

### Questions for Luther

1. **Known count mismatch.** Admin → Sections reads "Coming Soon · Most
   anticipated · 12 titles" while the Most Anticipated list holds 5. From the
   server source, `fetchAnticipated` returns `min(entries, item_limit)` and sets
   the section's `total_count` to that same number, so the API returns the
   curated count (5), capped by the row's `item_limit`; the admin's "12" is not
   the list length. Not confirmed against a live server.
2. **tvOS Select.** The TV spec says Select opens More info and Play/Pause
   toggles the clip, so the tvOS hero is one composite focus target with no
   separate Play button; an in-library title plays from its detail page. If the
   TV hero should instead offer a Play action directly, say so — it needs a
   second focus target and the focus model reworked.
3. **Requests off.** The coming-soon page is `GET /api/v2/requests/detail/...`,
   which the server refuses while requests are disabled
   (`ensureRequestsEnabled`). With requests off, a coming-soon item's page would
   error. A server-side capability-independent title detail (or leaving requests
   on) is needed; server is out of scope here.
4. **Trailer audio.** The clip plays through a plain `AVPlayer` with no audio
   session, so unmuting is best-effort and does not duck theme music. If sound
   should be guaranteed, that needs the shared audio-session policy.
