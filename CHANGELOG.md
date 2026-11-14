# Changelog

All notable changes to Market Monitor are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0]: https://github.com/Steinhagen/market-monitor-widget/releases/tag/v1.0
