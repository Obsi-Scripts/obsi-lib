# Changelog

All notable changes to obsi-lib are listed here. Versions follow [Semantic Versioning](https://semver.org).

## [1.0.0] - 2026-10-25

First public release.

### Added
- `ObsiLib` object, available through `@obsi-lib/init.lua` or `exports['obsi-lib']:get()` on both sides.
- Framework bridge for ESX Legacy, QBCore, QBX and custom frameworks (`editable/*/framework.lua`), with
  per-function patches (`ObsiEditable.frameworkPatch`) on top of any framework.
- Inventory bridge for ox_inventory, qb-inventory (v2 and legacy forks), codem-inventory, jaksam_inventory,
  custom inventories and the framework's own item functions, with automatic detection.
- Server modules: `player`, `job` (incl. offline job changes, duty, cops online), `money`, `license`,
  `society` (Renewed-Banking, okokBanking, qb-banking, qb-management, esx_society), `items` (incl. usable
  items and item catalog with images), `stash` (native stashes or a KVP fallback with its own menu),
  `vehicle` (plates, owned vehicles, keys), `notify`, `sound`, `state.push`, `callback`, `log` / `webhook`
  (Discord, queued) and `checkVersion`.
- Client modules: `player`, `job`, `money`, `license`, `items`, `stash`, `notify`, `ui` (progress bar,
  text UI, banner), `sound` (NUI player with live distance falloff, xsound when available), `dui`,
  `point`, `keybind`, `target` (ox_target / qb-target), `clothing` (illenium-appearance,
  fivem-appearance, qb-clothing, skinchanger), `game`, `vehicle`, `state` (reactive store) and `callback`.
- Built-in UI (React 19, Vite, Tailwind v4) in the Obsi look: notifications, progress bar, text UI and the
  sound player, with a configurable accent colour and a browser dev mode with mock data.
- English and Polish locales.
- Release check against github.com/Obsi-Scripts/obsi-lib.
