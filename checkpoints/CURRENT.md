# Current work

## Coming Soon hero on the native apps

Client repo: **silo-apple** (iOS, iPadOS, tvOS, macOS). `silo-android` is not
checked out on this machine, so Apple only. Branch: `Development`.

Contract and root cause: `docs/integration/coming-soon-hero.md`.

### Hero restyle (Prime card)

The phone hero was a full-bleed band; it is now the Prime-style carousel
**card** the reference calls for.

- Inset 16 from each page edge, max width 720 on a tablet, top corners radius
  20 and square bottom corners, height = width × 0.78.
- Backdrop and trailer both fill and centre-crop. The backdrop stays until the
  clip's layer reports a frame (`AVPlayerLayer.isReadyForDisplay`), then the
  clip crossfades in over 0.3 s.
- `hero_video_url` arrives as a **server-relative path**, so `SectionItem`
  decodes it through the same origin-resolving wrapper as the artwork
  (`@ArtworkURL`). Decoding it as a plain string handed `AVPlayer` a URL with
  no scheme or host, which it refused with `NSURLErrorUnsupportedURL` (-1002);
  the clip then sat at "waiting" with nothing on screen.
- The card's lower 45 % fades to the page colour, so it has no bottom edge; the
  card itself carries no background colour behind its rounded corners.
- Title: the item's clear logo (max 60 % of the card width, max height 64,
  aspect preserved) where the server sends one, else the name at 24 bold over
  two lines, shadowed, with no strip behind it.
- Metadata row: white `COMING SOON` pill (curated titles the library lacks
  only), grey `#3A3A3A` rating pill, runtime in white, year and first genre in
  grey, separated by spacing alone.
- Below it a calendar line with the release date.
- Mute control at the card's top-right: 40 × 40 radius 10, black 45 % with a
  1 pt white-25 % border, inside a 44 pt target, shown while the clip runs.
- Page dots centred: the active slide is an 18 × 6 white pill, the rest 6 × 6 at
  40 % white, 14 below the date line, width animated over 0.2 s.
- The card lasts as long as its clip: while a clip is on screen no timer competes
  with it and the end-of-item notification turns the card. A card with no clip
  (or with Reduce Motion on) turns after 8 s, and a clip that never draws a
  frame gives up after 20 s so a stuck clip cannot hang the carousel.
- The card carries no buttons — a tap anywhere opens the title.

### What changed earlier in this branch

A Home row the server flags `featured` renders as this hero at the top of Home
and is no longer also drawn as a poster row. A curated "Most Anticipated" slide
the library does not own opens its title page instead of the catalog item
detail, so it can never end in "not found".

- **Models** — `SectionItem` gains additive optional `availability`, `tmdbId`,
  `releaseDate`, `heroVideoUrl` plus `isComingSoon`, `comingSoonTmdbId`,
  `comingSoonMediaType`.
- **Routing** — `Route.card(...)` sends a coming-soon card to `.requestDetail`
  (the title page the web uses) and every other card to `.itemDetail`.
- **Home** — the first featured section is lifted to the top; iOS renders
  `PhoneHomeHero` below the header runway, tvOS renders `TVFeaturedHero` over
  the Skyline feed.
- **tvOS** — kept the previous layout and took only the fill/crossfade, the
  45 % fade, the logo, and the mute control's style (rendered as a
  non-focusable indicator; see Questions).
- **macOS** — its existing hero gates Play on `!isComingSoon` and routes More
  Info through `.card`.

### Verification

| # | Check | Result |
| --- | --- | --- |
| 1 | iOS build (scheme WeFlix, iPhone 17 / iOS 27 sim) | pass |
| 2 | tvOS build (scheme WeFlixTV, Apple TV 4K / tvOS 27 sim) | pass |
| 3 | macOS build (scheme WeFlixMac) | pass — `xcodebuild ... build` exits 0 |
| 4 | New warnings vs baseline | none |
| 5 | Existing tests (`WeFlixTests`, iPhone 17 sim, idle) | 3659 tests, 3 failures — all pre-existing and flaky/date-dependent (`CalendarTimeZoneTests` asserts a day that only matches in some weeks; `AsyncImageViewRetryTests` is a timing test). The 4 `PlayerSurfaceLayoutTests` that failed in a contended run pass in isolation. Nothing new in the changed areas |
| 6 | Live hero on the iPhone 17 sim against Luther's server | pass — inset rounded card, filled artwork, logo on "Verity" and text on "Other Mommy", `COMING SOON` + `R` + runtime + year, calendar date, centred pill dots, top-right mute control while the clip runs |
| 7 | Card dissolves into the page, no bottom edge | pass (screenshots) |
| 8 | Trailer plays | pass — item reaches `readyToPlay`, `rate 1.0`, layer `isReadyForDisplay`, no error; consecutive 1.2 s screenshots of the card differ by 25–52 mean channel whereas the rows below stay at 0.00 |
| 8a | Letterboxed clip fills the card | by construction — `AVPlayerLayer.videoGravity = .resizeAspectFill`; the specific reference clip was not replayed |
| 8b | Card lasts as long as the clip | pass — logged clip durations 129.6 s and 106.3 s, and the card turned only at a clip's end (`HEROADV` between the two), never at a fixed 8 s |
| 9 | Mute button inside the card and toggles | inside: pass. Toggling not driven — the tooling here has no tap action |
| 10 | Dots and swipe | dots pass (centred, active pill, count matches). Swipe not driven; the paged `TabView` is unchanged from the previous build |
| 11 | Other rows unchanged | pass — Continue Watching and Trending render as before beneath the card |
| 12 | Side-by-side evidence | `docs/design/hero-after.png` |
| 13 | silo-server `git status` unchanged | pass |

### Questions for Luther

1. **`docs/design/hero-reference-prime.png` is missing.** Only
   `hero-current-android.png` and a pre-existing `hero-after.png` were on disk,
   so the side-by-side pairs the Android reference with the iOS result. The
   earlier Android file is kept as `hero-after-android.png`.
2. **Metadata placement.** The spec puts the metadata row inside the card's
   fade; the Android reference screenshot puts it below the card. I followed
   the spec.
3. **In-library titles.** The spec's item 5 mentions Play "per the existing
   behaviour", but the hero has carried no buttons since the last change, so an
   owned title simply drops the `COMING SOON` pill and shows the calendar date.
4. **Separators and dates.** The metadata uses spacing only (no "·") per the
   spec's wording; the date line follows the user's locale, so it reads
   "7 Oct 2026" here rather than the spec image's "Oct 7, 2026".
5. **tvOS mute.** The TV hero is one composite focus owner and the Siri Remote
   has no mute button, so the mute control is a non-focusable indicator; a real
   toggle needs a second focus target and a reworked focus model.
6. **Requests off.** The coming-soon page is
   `GET /api/v2/requests/detail/...`, which the server refuses while requests
   are disabled. Server-side, out of scope here.
