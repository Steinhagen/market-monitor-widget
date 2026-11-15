# Changelog

All notable changes to Market Monitor are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Yahoo Finance headlines in German, French, Spanish and Italian, alongside
  English. The provider now sends the selected language's `lang`/`region` to
  Yahoo's search endpoint, so every edition keeps the same ticker tags, real
  publisher names and filtering as the English feed. Each item keeps its
  language for the badges and per-language views.

### Changed

- Yahoo Finance is no longer English-only: the source switch is enabled whenever
  the current language mode includes one of the five languages Yahoo localises.
  The same locale-aware search endpoint is used for every language; no separate
  per-language endpoint or title matching is needed.

### Fixed

- The news footer lists every source present in the visible list: one
  **More on Yahoo Finance** link per Yahoo language, plus **More on BVB** and
  **More on Google** when those sources contributed headlines. Each Yahoo link
  opens its edition's portal with the translated news route. Previously a single
  link followed the newest headline's source, so the **All** tab could show only
  Google even though it contained Yahoo and BVB headlines too.

## [1.1] - 2026-11-15

### Added

- News language modes: local only, local with an English backup, English only,
  and a multilingual picker with twenty languages. Google is queried once per
  selected language, Yahoo supplies English, and BVB supplies its Romanian or
  English attachment.
- Language badges on headlines when more than one language is configured,
  including on every source filter.
- Support for BVB articles with several attachments: classify each PDF as
  Romanian or English, choose the one matching the article title and use the
  English file's title in English mode.

### Changed

- The English backup now appends English Google and Yahoo headlines after the
  local ones, instead of appearing only when the local list was empty.
- The English fallback mode is hidden on English locales, where the local
  language is already English; an existing fallback setting is normalized to
  local-only when the settings are opened.
- In multilingual mode, BVB returns both the Romanian and English variants of an
  announcement when both languages are selected, so the BVB source filter shows
  both languages.
- News language settings are included in JSON backups.
- The language picker uses native language names and no longer marks one entry
  as "(local)".

### Fixed

- News dates older than a week now include the year, so an article from
  4 November 2025 is no longer shown as 4 November 2026.
- News sources follow the active locale: Yahoo is available when the local
  language is English, BVB uses Romanian, English or is skipped according to
  the active languages, and headlines are filtered by their actual language
  instead of assuming the local language is Romanian.
- Language badges stay visible on every source filter when several languages
  are configured, and are omitted when only one language is active.
- The panel indicator has three independent responsive modes: horizontal
  two-row scales from the applet height with exact row heights and a
  text-sized percentage pill; horizontal single-row scales from the panel
  height and fits its width to the content; vertical scales to the panel
  thickness with stable rows and smaller fonts for long values.
- The ticker and price stay prominent, the status tag is smaller, and the
  percentage pill and rows no longer overlap.
- Price/percentage alternation applies only to horizontal two-row; single-row
  and vertical show both values.

## [1.0] - 2026-11-15

Initial release of Market Monitor, a stock, crypto and currency widget for KDE
Plasma 6. It continues the Plasma Stock Monitor widget under a new name. The
pre-rename history is in [docs/CHANGELOG-legacy.md](docs/CHANGELOG-legacy.md).

### Added

- Single-stock and multi-stock views, including a side-by-side two-column layout
  with a draggable splitter.
- Unified tooltip cards for the watchlist and single-stock views, with the session
  date, update or cache state and a compact summary in single mode.
- Reference-line and candlestick charts with an optional trading-volume strip,
  ranges from 1D to Max, in-chart range and style controls, hover details, a price
  scale and a time axis.
- Optional analyst price-target markers, with the firm, rating and exact target
  shown on hover and in a details card.
- News from Yahoo Finance, Google and BVB, with per-source filters and configurable
  headline count and refresh interval.
- Pre-market and after-hours quotes, market status, and the last extended quote
  kept after the close.
- Configurable symbol display: full Yahoo Finance symbol, base symbol, or base
  symbol with an exchange badge across the watchlist, header and tooltip.
- Portfolio tracking by purchase lot, with average cost, per-lot currency,
  profit/loss, FX conversion and portfolio totals.
- Panel mode with price and change, optional alternating price/percentage,
  watchlist cycling, middle-click refresh and a transparent indicator option.
- Plasma and Application themes, light/dark/system colours, custom gain/loss
  colours, opacity and contrast handling.
- Configurable refresh interval, market-hours-only updates, weekend skipping, a
  startup retry and cached quotes shown while offline.
- Export and import of the watchlist, portfolio and settings as JSON.
- Configurable mouse actions for the widget.
- Ki18n localization with a complete Romanian translation.
- KDE Store packaging and automatic `.plasmoid` builds for version tags.

### Changed

- Rename the applet id from `io.github.steinhagen.plasmastockmonitor` to
  `io.github.steinhagen.marketmonitor`, and move the translation domain with it.
  Widgets placed under the old id have to be added again; their old settings are
  not migrated. Backups exported with the old id still import.
- Use the analyst cards' rounded, bordered surface for the market status popup.
- Replace the app icon with a Breeze-style candle-chart tile.

### Fixed

- Importing a backup no longer briefly shows the previous watchlist entries next
  to the imported ones.
- Analyst target markers now use a drawn, consistently centred up/down triangle.

[1.1]: https://github.com/Steinhagen/market-monitor-widget/releases/tag/v1.1
[1.0]: https://github.com/Steinhagen/market-monitor-widget/releases/tag/v1.0
