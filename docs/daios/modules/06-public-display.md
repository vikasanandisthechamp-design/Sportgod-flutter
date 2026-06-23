# Module 6 — Public Display Network

A managed network of TVs, kiosks, and digital signage that auto-tunes to local conditions.

## Devices
- 16:9 TVs (control rooms, bus stops, railway stations, malls)
- 9:16 portrait kiosks (panchayat offices, hospitals, shelters)
- Multi-screen video walls (SEOC)
- LED highway signs (per partnership with PWD/highways)

## Modes
| Mode | Trigger |
|---|---|
| Normal | No active severe events |
| Watch | Watch/Warning in district |
| Alert | Severe in district |
| Critical | Extreme; siren-coordinated |
| Drill | Banner clearly says DRILL |

## Controls
- Devices register via JWT-attested device ID.
- Content streamed via WS topic `display.<region>.<id>`.
- Auto-recovers from network drops; last good content persists.
- Hardware watchdog reboot on freeze.
- Tenant-managed templates and language rotation.

## Content rules
- Plain language, action verbs from canonical vocabulary.
- Multilingual rotation every 12 s in alert/critical modes.
- Helpline + SOS short-code always visible.
- Sign-language video track for top alerts (per tenant policy).

## Operations
- `display-svc` orchestrates rotations and emergencies.
- Failures alert SEOC operations; replacement playbook in runbook.
- Pre-monsoon health check on every device.

## Public-address & sirens
- `pa-adapter-svc` integrates with siren networks and partner PA (mosques, temples) on opt-in basis.
- Tone + voice message scripted from same template engine as alerts.
- Dual-authorisation for siren trigger (commander + duty officer) — sirens at night cause panic; safety > urgency unless Extreme.
