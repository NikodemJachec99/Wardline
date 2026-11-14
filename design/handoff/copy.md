# UI copy (English)

Keys are suggestions for `l10n` (ARB). Times and names are filled at runtime. Tone: short, calm, concrete; say what happened, when, and the one next step.

## Global
| Key | Text |
|---|---|
| `sim.note` | Simulation · fictional data (sign-in screen only) |
| `conn.live` | Live |
| `conn.reconnecting` | Reconnecting… |
| `conn.offline` | Offline |
| `offline.banner.title` | You're offline |
| `offline.banner.body` | Showing data from {time}. It may be out of date. |
| `offline.actionBlocked` | Changes need a connection |
| `offline.profileBlocked` | Transfers resume when you're back online. |
| `offline.noCache` | This patient hasn't been loaded on this device yet. Connect to the internet to open the record. |
| `online.back` | Back online · synced {time} |
| `cache.badge` | Cached · synced {time} |
| `cache.badgeStale` | Cached · synced {time} · may be outdated |

## Scan
| Key | Text |
|---|---|
| `scan.title` | Scan patient |
| `scan.hold` | Hold your phone near the patient's wristband |
| `scan.holdHint.ios` | Top edge of the iPhone, 1–2 cm from the band. |
| `scan.holdHint.android` | Hold the back of the phone to the wristband |
| `scan.rule` | Scanning opens the record — it never moves the patient. |
| `scan.start` | Start scanning |
| `scan.iosAlert` | Hold near the patient's wristband |
| `scan.identified` | Patient identified |
| `scan.invalid.title` | This tag doesn't contain a Wardline patient ID |
| `scan.invalid.body` | It may be a tag from another system or a damaged wristband. No record was opened. |
| `scan.unknown.title` | {code} isn't registered |
| `scan.unknown.body` | The wristband was read correctly, but no patient has this ID. Check the band, or find the patient by name. |
| `scan.noNfc.title` | NFC isn't available on this device |
| `scan.noNfc.body` | It's turned off or not supported. Switching to the QR code on the wristband so you can keep working. |
| `scan.camera.title` | Camera access is off |
| `scan.camera.body` | Wardline needs the camera to read wristband QR codes. Turn it on in Settings › Wardline › Camera. |
| `scan.qr.hint` | Point at the QR code on the wristband |
| `scan.cancelled` | (no message: quiet return) |

## Transfer (Nurse)
| Key | Text |
|---|---|
| `transfer.sheet.title` | Move {patient} |
| `transfer.sheet.from` | From {location} · {floor} |
| `transfer.search` | Search departments |
| `transfer.current` | Current |
| `transfer.confirm.title` | Confirm transfer |
| `transfer.confirm.performedBy` | Performed by |
| `transfer.confirm.statusUnchanged` | {status} · unchanged |
| `transfer.confirm.cta` | Confirm transfer |
| `transfer.saving` | Confirming… |
| `transfer.saving.hint` | Waiting for the server |
| `transfer.success.title` | Patient moved to {location} |
| `transfer.success.body` | Confirmed by the server at {time}. Every device sees it now. |
| `transfer.conflict.title` | Patient was already moved |
| `transfer.conflict.body` | Your change wasn't saved. |
| `transfer.conflict.cta` | Refresh and choose again |
| `transfer.timeout.title` | We couldn't confirm the transfer |
| `transfer.timeout.body` | The server didn't answer within 10 seconds. It may already be saved. Checking won't move {firstName} twice. |
| `transfer.timeout.cta` | Check status |

## Status (Doctor)
| Key | Text |
|---|---|
| `status.sheet.title` | Change status |
| `status.note` | Location doesn't change. {firstName} stays in {location}. |
| `status.reason` | Reason (optional) |
| `status.reason.required` | Reason · required for discharge |
| `status.save` | Save status |
| `status.discharge` | Discharge patient |
| `status.saved.title` | Status updated |
| `status.saved.body` | {status} · location unchanged |

## Lists, empty and errors
| Key | Text |
|---|---|
| `patients.search` | Name, ID or department |
| `patients.empty` | No patients match "{query}" |
| `patients.empty.body` | Check the spelling, or search by patient ID, e.g. HPT-7K3M9QX2. |
| `load.failed.title` | Couldn't load patients |
| `load.failed.body` | The server didn't respond. Data cached at {time} is still available. |
| `notifications.empty` | You're all caught up |
| `history.empty` | No transfers {direction} {department} today |
| `perm.nurseOnly` | Only nurses can move patients. (Server error PT403; the UI never offers this action.) |
