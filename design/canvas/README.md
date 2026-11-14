# Wardline design canvas (source)

Source files of the Wardline design canvas: https://claude.ai/artifact/W1xGQWDTSiCacKQMSiUwqu (private until shared from its Share menu).

> SIMULATION ONLY. All names, IDs and numbers are fictional.

- `canvas.json`: the canvas index (pages, artboard positions, titles).
- `*.dc.html`: one file per artboard. They are Design Component pages: HTML markup + inline styles + a small `class Component extends DCLogic` script. They render inside the canvas editor (they load its `support.js` runtime), so opening them straight from GitHub shows raw markup, not the design. To view or click through them, use the canvas link.

To implement, use `../handoff/` (tokens, Flutter ThemeExtension, component and screen specs). These files are the visual reference: exact colours, spacing and copy can be read from the inline styles.

## Pages and artboards

| Page | Artboards |
|---|---|
| Design system | `Main` (brand, app icon, rules) · `Colour` · `Type` · `Layout` (space, radius, elevation, motion) · `Controls` · `Patient` · `Dashboard` · `States` · `Navigation` |
| Screens | `DashA` · `DashB` (chosen) · `DashDoctor` · `DashLoading` · `Profile` · `ProfileDoctor` · `ProfileOffline` · `ScanNfc` · `ScanIos` · `ScanSuccess` · `ScanQr` · `ScanEdge` |
| Journeys | `TransferFlow` · `StatusFlow` · `Login` · `PatientsList` · `HistoryFlow` · `Account` · `OfflineMode` · `Admin` · `Platform` (Android + large text) |
| Map & analytics | `MapLive` · `MapStates` · `Analytics` · `WardMonitor` · `DemoMode` |
| Prototype & handoff | `Proto` (flows 1–5) · `ProtoSync` (two devices) · `MotionSpec` · `Handoff` |

This folder is a snapshot. The canvas is the live version; re-export here when it changes.
