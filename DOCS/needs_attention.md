# Needs Attention

_Added 2026-09-20. These items came out of the Antigravity grill verification (`Handoff for agents and Todos/ANTIGRAVRITY_GRILL/claude_sol.md`, issues_open.md §78). They need the founder: account access, a real device, a decision, or the Blaze plan. A coding agent can't close them._

## Your accounts

- [ ] **Back up the keystore and confirm Play App Signing. Do this today.** Put `throttleiq-release.keystore`, the passwords in `app/android/key.properties`, `secrets/*.json`, and `secret/creds.txt` in a password manager. Then move the keystore out of the repo folder (claude_sol §2.6.2).
- [ ] **Add testers to the Play internal track.** It has zero testers today (claude_sol §4.4).
- [ ] **Fill in the Play Data Safety form and the full-screen alert declaration.** Data Safety needs: audio (voice notes), precise location, and crash logs. The full-screen intent declaration is required for the crash countdown (69.O1, 69.O8).
- [ ] **Lock down the Cloudinary upload preset in its dashboard.** On `throttleiq_unsigned`, set allowed formats, a max file size, a locked folder, and a usage alert (claude_sol §1.4.4).

## Decisions

- [ ] **a. Deleting a bike:** archive it by default? (recommended)
- [ ] **b. Crash alerts:** Path B, where the phone opens a pre-filled text to your contacts, can be built now without Blaze. Or wait for real server-side SMS?
- [ ] **c. Pitch Slide 9:** does the team on the slide exist? If not, rewrite it as a solo founder hiring those roles.
- [ ] **d. Profile tab:** rename it to "Garage"?
- [ ] **e. §74:** are the dark cards on Retro Light intentional?

## Needs Blaze

- [ ] Real SMS and escalation
- [ ] Signed Cloudinary uploads
- [ ] Full account deletion
- [ ] Adding new followers to old posts

## Deploys

- [ ] Rules and hosting, after the fixes land. These go public, so confirm before each deploy.
