# Wardline Design System — entire project

This project’s pages, files, and uploads as this browser tab had them at export.
Anything left out is listed below.

## Contents

### Design system

- `Main.dc.html` — 01 · Brand & product rules
- `Colour.dc.html` — 02 · Colour tokens
- `Type.dc.html` — 03 · Type & icons
- `Layout.dc.html` — 04 · Space, radius, elevation, motion
- `Controls.dc.html` — 05 · Controls
- `Patient.dc.html` — 06 · Patient & history
- `Dashboard.dc.html` — 07 · Dashboard & map
- `States.dc.html` — 08 · Connectivity & feedback
- `Navigation.dc.html` — 09 · Navigation & sheets

### Screens

- `DashA.dc.html` — Dashboard · A · Report (alternative)
- `DashB.dc.html` — Dashboard · B · Control room (chosen)
- `DashDoctor.dc.html` — Dashboard · Doctor
- `DashLoading.dc.html` — Dashboard · Loading
- `Profile.dc.html` — Patient profile · Nurse (full scroll)
- `ProfileDoctor.dc.html` — Patient profile · Doctor
- `ProfileOffline.dc.html` — Patient profile · Offline
- `ScanNfc.dc.html` — Scan · NFC ready
- `ScanIos.dc.html` — Scan · iOS system sheet (placeholder)
- `ScanSuccess.dc.html` — Scan · Read success + quick summary
- `ScanQr.dc.html` — Scan · QR mode
- `ScanEdge.dc.html` — Scan · Error & edge states

### Journeys

- `TransferFlow.dc.html` — J1 · Transfer journey (Nurse) · 1 → 7
- `StatusFlow.dc.html` — J2 · Change status (Doctor)
- `Login.dc.html` — J3 · Sign in
- `PatientsList.dc.html` — J4 · Patients list · states + filters
- `HistoryFlow.dc.html` — J5 · History, department history, day timeline
- `Account.dc.html` — J6 · Notifications & settings
- `OfflineMode.dc.html` — J7 · Optional: sync queue & pending transfers
- `Admin.dc.html` — J8 · Optional: admin panel
- `Platform.dc.html` — J9 · Android + large text

### Map & analytics

- `MapLive.dc.html` — M1 · Hospital map · live (try it)
- `MapStates.dc.html` — M2 · Map states: department, find patient, route, list, mini map
- `Analytics.dc.html` — A1 · Analytics · tablet 1194 wide
- `WardMonitor.dc.html` — W1 · Ward monitor · Internal Medicine · 1194×834
- `DemoMode.dc.html` — D1 · Demo mode (admin)

### Prototype & handoff

- `Proto.dc.html` — P1 · Clickable prototype · flows 1–5 (press Play)
- `ProtoSync.dc.html` — P2 · Two devices · realtime sync (press Play)
- `MotionSpec.dc.html` — H1 · Motion spec
- `Handoff.dc.html` — H2 · Handoff · screens, platform, accessibility

### Other files

- `canvas.json` — the canvas: its pages, where each artboard sits, its notes and shapes
- `_runtime/` — what runs the pages in a browser; not part of the design

## Viewing

To view a page, start a local web server in this folder (for example `python3 -m http.server`), then open an artboard’s `.dc.html` file through it. Opening the file directly may not work, because some browsers block its scripts.

## Left out of this export

The export never includes hidden files (files whose names start with a dot) or
files the editor keeps for its own use.
