# What Bangladeshi riders ask in public bike groups (2026-10-21)

Source: Apify `apify/facebook-groups-scraper`, 375 newest posts from 30 Sep to 21 Oct 2026, cost $2.65 (issues_open §105.3).

| Group | Posts | Use |
|---|---|---|
| Freewheelers Club BD (`groups/fcb.zone`) | 125 | Best source: long, technical maintenance questions |
| BikeBD (`groups/bikebdofficial`) | 125 | Mixed: plates, launches, tours, paperwork |
| Motorcycle Valley (`groups/MotorcycleValley`) | 125 | Mostly ads and reels; ~100 posts have no text. Skip next time |
| BD Biker Club, Gixxer Riders BD, Royal Enfield BD | 0 | Private, or the link is wrong |

103 posts had no text (photo or video only). Counts below are approximate and come from reading the ~270 text posts. No names, posts or user data were kept in the repo. The raw export is at `DOCS/apify/2026-10-21_fb-bike-groups/items.json` (gitignored; all scrapes and lessons: `DOCS/apify/README.md`).

## Topics, most discussed first

1. **Front number plate rule (~35 posts, highest engagement: 1,225 and 731 likes).** BRTA requires a manual front plate (285 × 50 mm, aluminium or steel, Bangla text) by **15 Nov 2026**. People ask where to get embossed plates (Mirpur, Dhaka), which clamp fits their model (Gixxer, Hornet, Livo, X-Blade, Taro GP-1), and whether modifying the bike to fit one counts as an illegal mod. Many complain about the size and the 30-day deadline. One rider asked what to do after losing the plate's RFID chip.
2. **Engine diagnosis (~18).** Riders describe a symptom and ask for the cause: knocking with a pillion, metallic noise after a rebuild, overheating, idle RPM dropping, RPM hunting, a black spark plug, a wobbling rear wheel, mirror vibration. They usually include odometer reading, tappet clearance and plug type, and ask how much the fix will cost.
3. **Parts: where to buy, and are they genuine (~15).** Mostly about Mirpur 10 and Bangshal. People ask about clutch plates (FCC vs MK; Indian vs Chinese FCC lasting 50k vs 10k km), fuel pump motors, brake hose washers, monoshocks, clamps and air filters. A recurring question is how to tell a genuine part from a fake.
4. **Mileage (~12).** Owners report 20 to 32 km/L, try fixes (tappet, carburettor tuning, plug, octane booster) and ask what to do next. Fuel prices are going up, so several people ask which 150 cc bike gets 50+ km/L in the city. **One post asked why a fuel-log app shows the wrong mileage (10 comments).**
5. **Buying advice (~10).** Head-to-head choices (FZS V2 vs Hornet 2.0 vs N160; NX200 vs V-Strom SX 250; moving up to 250 cc and wanting 50–70k km of durability), expected launch prices (Hero Xtreme 250R on 30 Oct), and questions like why a Yamaha costs more than an Indian Hero.
6. **Engine oil (~9).** Which grade and brand for a given bike, odometer reading and riding style. Where to find genuine oil in Dhanmondi, Barisal and Chattogram. Moving to a thicker oil because the engine burns oil.
7. **Gear (~9).** Helmets around ৳7–8k (LS2 vs MT), intercoms (battery life, pairing across brands), fog lights, disc locks, and anti-theft against GPS jammers.
8. **Finding a trustworthy mechanic (~7).** "A good mechanic near Mirpur, Sreemangal or Dhaka who doesn't rush commuter bikes." Riders avoid official service centres because they won't fit parts bought elsewhere and their parts cost more.
9. **BRTA paperwork (~7).** Name transfer (waiting for biometrics, the original dealer having closed), tax token renewal before the fine waiver ends (29 Oct), converting analogue papers to digital, colour-change fees, whether a single seat is legal.
10. **Warranty and dealer complaints (~5).** A tank warranty refused because services weren't stamped in the service book, a cracked rim on a tour with no help from the dealer, paint peeling on a new bike.
11. **Tours and routes (~6).** Whether Bandarban, Tindu and Ruma are open and need BGB permission, the Kanchenjunga view from Panchagarh, booking resorts ahead in season.
12. **DIY how-tos get high engagement.** Chain cleaning with kerosene (43 likes), changing brake fluid yourself (122 likes), cleaning a spark plug.
13. One-offs: where to park overnight in Dhaka for several days (50 comments); a fuel pump that short-filled 2 L as 1.75 L; a kite-string neck guard; a riding academy for emergency manoeuvres.

## Ideas for ThrottleIQ (not built; for the founder to rank)

- **Front-plate guide before 15 Nov (time-limited).** A forum thread, or a pinned card in Places, listing the BRTA spec, clamp fixes per model and places that make embossed plates. It answers the most-asked question this month, and the plate makers could be added as Places.
- **Prove fuel-log accuracy.** Riders distrust mileage apps. Our km/L is calculated between full-tank fills; show that method in the fuel log ("calculated between full tanks; partial fills are added up"), so we answer the "why is the app wrong" question before anyone asks it.
- **Symptom-first forum template.** Diagnosis posts already include bike, odometer, tappet clearance, plug and symptom. A "Help: problem" post template that fills in the bike and odometer from Garage would make these posts faster to write and easier to answer.
- **Service-book proof for warranties.** The tank-warranty refusal happened because services weren't stamped. The maintenance service log could export a dated service history (PDF/share) as backup evidence.
- **Places: genuine oil and parts.** "Where is genuine X in my area" is common. Tags like "authorised oil dealer" or "genuine parts" on Parts places, with a rider vote, would answer it. Ties in with §104.1 (fix the read cost before adding more).
- **Papers reminders: add tax-token fine-waiver dates.** The Papers card already tracks expiry dates; one-off BRTA deadlines (fine waiver ends 29 Oct, plate rule 15 Nov) could go out as a broadcast.
- Already covered: forum topics Mileage Tips and Engine Oil Review exist; maintenance forecast and running costs exist.

## Next scrape (if any)

Skip Motorcycle Valley (ads). Freewheelers is worth a repeat in a few months. The bigger groups (BD Biker Club, Gixxer Riders) need correct public URLs, found by hand on Facebook.
