# Changelog

## 1.2.0

### Added
- Invert ring order: show Rupture on the left and Garrote on the right, each
  icon keeping its own ring. Toggle it with the new checkbox under Appearance
  in the options window or with `/rbt invert`. Applies live.

### Fixed
- Options checkboxes now show the current setting when the window is reopened
  after it was changed elsewhere (minimap right-click, slash commands).

## 1.1.0

### Added
- Options window (`/rbt` or left-click the minimap icon) with the Garrote icon
  as its portrait. Sliders and checkboxes apply **live**: ring size, width,
  spacing, segment gap and max enemies no longer need `/reload`.
- Minimap icon (Garrote): left-click toggles options, right-click locks /
  unlocks the frame, drag moves it around the minimap. Follows the minimap's
  actual shape and size (round, square and mixed shapes via `GetMinimapShape`).
- `/rbt space <px>` command for the spacing between rings.

### Changed
- `/rbt` now opens the options window instead of toggling the lock.
- The `AuraContainer` chain is built in chunks of 8 per frame, avoiding the
  FPS hitch when the display is rebuilt.

### Fixed
- `UNIT_FLAGS` and `UNIT_THREAT_LIST_UPDATE` only trigger a rescan for
  `nameplateN` units instead of every unit in the game.
- The tracker no longer errors if an unhandled event fires.

## 1.0.0

- First release.
- Garrote and Rupture rings with one segment per engaged enemy, filling clockwise.
- Bleeding/engaged count on each icon.
- Fill colour by coverage: red, then green at 25%, blue at 50%, purple at 75%, orange at 100%.
- Slash commands for position, size, ring width, segment gap and enemy cap.