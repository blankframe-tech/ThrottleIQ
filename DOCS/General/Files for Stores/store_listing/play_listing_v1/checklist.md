# Play production listing — checklist (v1, 2026-11-01)

For the day Google grants production access (after 12 testers × 14 days, see
`DOCS/Handoffs for Non Coding Agents/marketing/closed_test_recruitment.DRAFT.md`).

| File | What |
|---|---|
| `en.md` | Title, short, full description, What's new (+35), 8 screenshot captions |
| `bn.md` | The same in Bangla, **machine-drafted, needs native review (#23)** |
| `content_rating.md` | IARC questionnaire answers |
| `scripts/check_listing_lengths.js` | Fails if title > 30, short > 80, full > 4,000 or What's new > 500 |

## Before pasting

- [ ] `node scripts/check_listing_lengths.js` prints `ok` for both files (it also runs in
      `scripts` `npm test`, so CI catches an edit that breaks a limit).
- [ ] Bangla reviewed by a native reader: review chunk
      `DOCS/Handoffs for Non Coding Agents/bn_review_chunks/01_store_listing.md`. Paste
      fixes into `bn.md`, re-run the checker.
- [ ] Nothing in either file promises crash detection, SOS, automatic alerts, SMS or
      email to contacts. (Crash detection is shadow mode: it records, it sends nothing.)

## Screenshots (phone; check the size rules shown in Play Console)

Reuse 1–6 from `systems/landing-page/throttle-iq/assets/screenshots/`:
`maintenance.jpg`, `record.jpg`, `ride-summary.jpg`, `garage.jpg`, `stats.jpg`,
`places.jpg`. Check each still matches the current UI before uploading.

**Owner must capture 2** on the current build, light theme, with a real-looking bike:
- [ ] 7. **Garage service log:** Garage → bike → Maintenance → service history with one
      visit logged (bill and receipt photo visible).
- [ ] 8. **Papers reminder:** Maintenance → Papers with a tax token due within 30 days.

For a Bangla screenshot set, switch the app to Bangla and capture the same 8.

## Play Console steps

- [ ] Store presence → Main store listing: paste `en.md` fields; upload icon
      (`../throttleiq_playstore_icon_512.png`), feature graphic
      (`../throttleiq_feature_graphic_1024x500.png`) and the 8 screenshots.
- [ ] Manage translations → Bengali (bn-BD): paste `bn.md` fields.
- [ ] App content → Content ratings: answer from `content_rating.md`.
- [ ] App content → Privacy policy `https://throttleiqfb.web.app/privacy.html`, Data
      safety (`../throttleiq_data_safety.csv`), Target audience 18+, Ads: No.
- [ ] Production release: release notes = the What's new block for the build you
      promote (update it if that build isn't +35).
