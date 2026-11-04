# Coming Soon hero — client/server contract

What the app needs from `silo-server` to render a Home row flagged as a hero
banner as a hero carousel (instead of a poster row), and why a curated
"Most anticipated" slide currently ends in "not found".

Server-side source of truth: `silo-server/docs/architecture/anticipated.md`.
`silo-server` is read-only for this integration; nothing here changes it.

## Endpoints the app uses

All paths are on the same origin and session/auth the app already uses
(`APIv2Client` + `WeFlixAPI`), so no new transport or auth is required.

| Purpose | Endpoint | App entry point |
| --- | --- | --- |
| Home layout + cards | `GET /api/v2/home/sections` (aggregate section read) | `StartupContentPrefetcher.fetchHomeSections()` → `SectionsResponse` |
| Home capabilities | `GET /api/v2/home/capabilities` | `anticipated_supported` feature flag |
| Non-library title details | `GET /api/v2/requests/detail/{media_type}/{tmdb_id}` | `WeFlixAPI.requestsDetail(mediaType:tmdbId:)` |
| A row's full page | the row-backed catalog page for the section | `Route.sectionCatalog` |

The hero clip URL is **not** a separate call: it is a member of the card
(`hero_video_url`), presigned and long-lived, served by the section read.

## Fields that matter

### On a section (the hero flag)

`ResolvedSection` (wire `Section`):

- `featured: Bool` — "the row is its page's hero banner". This is the only
  field that marks a row for hero rendering. It is **not** specific to the
  anticipated row: any row can be flagged.

### On a card (the coming-soon item)

An unowned curated slide is a **synthetic external item**, not a catalog row.
Its card is the shared `CatalogItem` with four additive members present only on
that slide:

- `content_id`: `ext:<media_type>-<tmdb_id>` (the discriminator the server
  builds; clients should branch on `availability`, not the prefix).
- `availability`: `"unreleased"` (library lacks it) or `"released_unowned"`
  (reserved for a server that can tell a title is obtainable; this server never
  sends it). An owned slide is an ordinary catalog card and carries **no**
  `availability`.
- `tmdb_id`: the title's TMDB id — what the title page and a request use.
- `in_watchlist` / `requestable`: viewer request state (this server leaves them
  unpopulated today).
- `hero_video_url`: a short clip of the title's trailer (from `anticipated_clips`
  for a synthetic id, `hero_clips` for a catalog id). Absent when the server has
  no clip.
- `poster_url` / `backdrop_url` / `logo_url`: composed from TMDB's image CDN
  (`https://image.tmdb.org/t/p/...`), **not** the asset store. They are absolute
  URLs, so the app's `ArtworkURL` decoder passes them through unchanged.

Display fields come from the stored snapshot: `title`, `year`, `runtime`,
`release_date` (`YYYY-MM-DD`), `overview`, `genres`, `content_rating`.

### On a non-library title's detail

`GET /api/v2/requests/detail/{media_type}/{tmdb_id}` → `RequestMediaDetail`:
`title`, `overview`, `poster_path`, `backdrop_path`, `release_date`, `year`,
`runtime`, `genres`, `cast`, `availability`, `library_content_id`. This is the
document the web's `/title/<media_type>/<tmdb_id>` page renders, with request
actions in place of playback.

## How the web decides Coming soon vs Play

From `availability` alone (never the id prefix): `unreleased` → a
"Coming soon · <date>" badge and More Info at `/title/<type>/<tmdb>`; a catalog
card (no `availability`) → Play. The badge only shows the snapshot date while it
is still ahead.

## Trailer source

An unowned title has no `item_videos` row, so its trailer is TMDB's video
(`trailer_site` / `trailer_key`), cut into a clip and published under the shared
`hero-clips/` object namespace by `GenerateHeroClipsTask`'s second pass over
`anticipated_clips`. Delivery merges both clip stores and the card carries the
resulting URL as `hero_video_url`.

## Root cause of "not found"

1. `ResolvedSection.featured` already decodes into the app (`Models.swift`).
2. `HomeView.feedSection` renders **every** section through `feedRow`
   (a poster rail) on iOS/iPadOS/tvOS. Only macOS hoists a leading featured
   section into `MacFeaturedHero`. So on the phones/tv the row shows as poster
   cards.
3. Tapping a card calls `Route.itemDetail(destinationContentId: item.contentId,
   sectionItem: item)`. For a synthetic slide `contentId` is `ext:<type>-<tmdb>`,
   so `ItemDetailViewModel.loadDetail` requests
   `GET /api/v2/catalog/items/ext:<type>-<tmdb>` and the server answers **404**.
   `ErrorState.isNotFound` drives the "not found"/unavailable copy.

The fix is client-side: detect the hero flag, render a hero carousel, and route
an unowned slide to the existing request/title detail page instead of the
catalog item detail.

## What the app had to add

- `SectionItem`: `availability`, `tmdbId`, `heroVideoUrl`, `releaseDate` (all
  additive, optional — unknown/absent fields never break other rows).
- A Home hero carousel for iOS/iPadOS and tvOS that reuses `AsyncImageView`,
  AVFoundation (muted clip), `WeFlixTheme`, and the existing routes.
- The iOS/iPadOS hero has no call-to-action buttons: a tap anywhere on it opens
  the title's page through `Route.card` — the title page for an unowned card, the
  item page for an owned one — which is how Prime's mobile hero behaves.
