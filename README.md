# GroomerBook (iOS)

Mobile dog groomer's book — dog profiles (grooming recipe, bite-risk flag, vaccine expiry), owner profiles (contact, preferences), appointments with drive buffer and no-show tracking, one-tap "on my way" text.

## Why this exists (pain-point sourced)

Every feature maps to a real groomer pain point (see `../SaaS项目/research/宠物美容师App-痛点清单与施工单-2026-11-07.md`):
- Recipe reuse (P1) — "started at a new salon, almost no notes, got bitten"
- Bite risk flag (P2) — mission-critical safety info living in memory
- Owner contact + preferences (P3)
- No-show counter + deposit hint (P4) — mobile clients forget you come to THEM
- On-my-way text template (P5) — wet hands all day, typing kills
- Vaccine expiry (P6)
- 6-week rebook loop (P7) — missing it = 30-50% revenue

## Status

v1.0 MVP — pure local (SwiftData-free, UserDefaults+Codable), no account, no network. English-first listing per house rule.

- [x] Data layer (Owner/Dog/Appointment + store)
- [x] UI: Today / Dogs / Owners tabs, editors, no-show warnings, message template copy
- [ ] CI green → TestFlight
- [ ] App Store listing via `/ios-appstore-launch`

## Privacy

No account. No network. Everything stays on device.

## License

MIT
