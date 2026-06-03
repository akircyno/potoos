# Potoos Build Roadmap

Complete ordered checklist from current state to App Store launch.
Update the status column as each step is completed.

---

## Status Key

| Symbol | Meaning |
|---|---|
| ✅ | Done |
| 🔄 | In progress |
| ⬜ | Not started |
| 🚨 | App Store required — will be rejected without this |

---

## Phase 1 — Infrastructure

| # | Task | Status | Notes |
|---|---|---|---|
| 1.1 | Create `potoos.storage@gmail.com` — fresh Google Drive account | ✅ | No file migration needed, no users yet |
| 1.2 | Update Supabase Edge Functions credentials to new storage account | ✅ | After 1.1 |
| 1.3 | Rename GitHub repo `litratolink` → `potoos` | ✅ | Do after Supabase + Google OAuth updated |
| 1.4 | Add new GitHub Pages URL to Supabase auth redirect URLs | ✅ | Dashboard → Authentication → URL Config |
| 1.5 | Update Google OAuth consent screen app name to "Potoos" | ✅ | Google Cloud Console |
| 1.6 | Update `app/env.properties` web redirect URL to new GitHub Pages URL | ✅ | After 1.3 |

---

## Phase 2 — UI/UX Design Pass

| # | Task | Status | Notes |
|---|---|---|---|
| 2.1 | Login screen redesign | ⬜ | |
| 2.2 | Home / My Albums screen redesign | ⬜ | |
| 2.3 | Album Details screen redesign | ⬜ | |
| 2.4 | Upload screen redesign | ⬜ | |
| 2.5 | Save All screen redesign | ⬜ | |
| 2.6 | Members screen redesign | ⬜ | |
| 2.7 | Profile screen redesign | ⬜ | |
| 2.8 | Typography, spacing, and color consistency audit | ⬜ | |

---

## Phase 3 — App Icon

| # | Task | Status | Notes |
|---|---|---|---|
| 3.1 | Generate final Poto app icon (iOS, Android, PWA sizes) | ⬜ | Use `poto-app-icon-reference.png` as base |
| 3.2 | Replace placeholder icons across all platforms | ⬜ | iOS, Android, web favicon, PWA manifest icons |

---

## Phase 4 — Onboarding

| # | Task | Status | Notes |
|---|---|---|---|
| 4.1 | Design 2–3 screen first-run walkthrough | ⬜ | What is Potoos, how to create album, how to invite |
| 4.2 | Implement onboarding flow in Flutter | ⬜ | Show only on first launch, skip on return |
| 4.3 | Add Poto mascot to onboarding screens | ⬜ | |

---

## Phase 5 — Animation

| # | Task | Status | Notes |
|---|---|---|---|
| 5.1 | Generate sprite frame sets (idle wave ✅, guarding, happy) | 🔄 | Wave done. Need guarding + happy frame sets |
| 5.2 | Clean sprite frames (remove.bg, center alignment) | ⬜ | |
| 5.3 | Assemble sprite sheets in Aseprite or TexturePacker | ⬜ | |
| 5.4 | Wire sprite sheets into `poto_mascot.dart` | ⬜ | Tell Claude "sprite sheets ready" |
| 5.5 | Screen transition animations | ⬜ | |
| 5.6 | Micro-interactions (button press, upload success, save complete) | ⬜ | |
| 5.7 | Short brand video (Sora/Runway → CapCut) | ⬜ | See `docs/potoos-brand/short-video-animation-plan.md` |

---

## Phase 6 — Push Notifications

| # | Task | Status | Notes |
|---|---|---|---|
| 6.1 | Set up FCM project | ⬜ | Firebase Console |
| 6.2 | Add APNs key to FCM (iOS) | ⬜ | Apple Developer portal |
| 6.3 | Add FCM credentials to Supabase | ⬜ | |
| 6.4 | Write Supabase Edge Function to send notifications | ⬜ | On upload, invite, Save All |
| 6.5 | Add push notification permission request in Flutter app | ⬜ | iOS prompt, Android channel |
| 6.6 | Test on real device (not simulator) | ⬜ | |

---

## Phase 7 — Email Notifications

| # | Task | Status | Notes |
|---|---|---|---|
| 7.1 | Set up transactional email (Resend or SendGrid — free tier) | ⬜ | |
| 7.2 | Album invite email (sent when user is invited) | ⬜ | |
| 7.3 | New upload notification email (optional, user setting) | ⬜ | |

---

## Phase 8 — Performance & Reliability

| # | Task | Status | Notes |
|---|---|---|---|
| 8.1 | Thumbnail loading speed optimization | ⬜ | |
| 8.2 | Upload retry logic on failure | ⬜ | |
| 8.3 | Offline / no-connection state handling | ⬜ | Show friendly message, not blank screen |
| 8.4 | Large file warning on cellular connection | ⬜ | Warn before uploading video on mobile data |

---

## Phase 9 — Analytics

| # | Task | Status | Notes |
|---|---|---|---|
| 9.1 | Set up Firebase Analytics (free) | ⬜ | |
| 9.2 | Track key events: album created, upload success, save all used | ⬜ | |
| 9.3 | Monitor upload success/failure rate | ⬜ | |

---

## Phase 10 — Crash Reporting

| # | Task | Status | Notes |
|---|---|---|---|
| 10.1 | Set up Firebase Crashlytics or Sentry | ⬜ | Must be done before beta testing |
| 10.2 | Verify crashes are appearing in dashboard | ⬜ | Trigger a test crash |

---

## Phase 11 — Security Hardening

| # | Task | Status | Notes |
|---|---|---|---|
| 11.1 | Full Supabase RLS policy audit | ⬜ | Verify every table has correct row-level security |
| 11.2 | Confirm no private file URLs are publicly accessible | ⬜ | |
| 11.3 | Rate limiting on Edge Functions | ⬜ | Prevent upload/invite spam |
| 11.4 | File access permission check on every download | ⬜ | |
| 11.5 | Penetration test key flows (invite, upload, download) | ⬜ | Manual or automated |

---

## Phase 12 — Account Deletion 🚨

| # | Task | Status | Notes |
|---|---|---|---|
| 12.1 | Add "Delete Account" option in Profile screen | ⬜ | **Apple will reject without this** |
| 12.2 | Supabase Edge Function: delete user record, memberships, uploaded files | ⬜ | Full data wipe |
| 12.3 | Remove files from Google Drive on account deletion | ⬜ | |
| 12.4 | Confirmation dialog before deletion | ⬜ | Cannot be undone |

---

## Phase 13 — Legal & Support

| # | Task | Status | Notes |
|---|---|---|---|
| 13.1 | Create support contact (email or contact form) | ⬜ | **App Store required** — e.g., support@potoos.app |
| 13.2 | Publish Privacy Policy at a live URL | ⬜ | **App Store required** — GitHub Pages or Notion is fine |
| 13.3 | Publish Terms of Use at a live URL | ⬜ | |
| 13.4 | Link Privacy Policy and Terms inside the app | ⬜ | Profile or Settings screen |

---

## Phase 14 — App Store Assets

| # | Task | Status | Notes |
|---|---|---|---|
| 14.1 | Screenshots — iPhone (6.9", 6.5") | ⬜ | Required sizes |
| 14.2 | Screenshots — iPad (13", 12.9") | ⬜ | Required if iPad is supported |
| 14.3 | App Store description (short + long) | ⬜ | See `docs/# LitratoLink App Store and TestFli.md` for draft |
| 14.4 | App Store keywords | ⬜ | Max 100 characters |
| 14.5 | App preview video (optional but recommended) | ⬜ | 15–30 seconds, use brand video |
| 14.6 | Prepare demo Google account for App Review | ⬜ | **App Store required** — reviewers need to log in |
| 14.7 | Prepare demo album with sample photos for reviewers | ⬜ | |
| 14.8 | Write App Review notes | ⬜ | Explain Google login, demo steps |

---

## Phase 15 — iPad Layout

| # | Task | Status | Notes |
|---|---|---|---|
| 15.1 | Album grid adapts to larger screen | ⬜ | More columns on iPad |
| 15.2 | Split view / side panel consideration | ⬜ | Optional but polish |
| 15.3 | Test all flows on iPad simulator | ⬜ | |

---

## Phase 16 — Beta Testing (TestFlight)

| # | Task | Status | Notes |
|---|---|---|---|
| 16.1 | Enroll in Apple Developer Program | ⬜ | **$99/year USD** (~₱5,500) |
| 16.2 | Create App Store Connect app record | ⬜ | Bundle ID: `com.potoos.app` |
| 16.3 | Archive and upload build from Xcode on Mac | ⬜ | `flutter build ipa` |
| 16.4 | Invite internal testers (you + close circle) | ⬜ | |
| 16.5 | Collect and fix bugs from real device testing | ⬜ | |
| 16.6 | Expand to 10–30 external testers | ⬜ | After internal is stable |

---

## Phase 17 — iOS App Store Launch

| # | Task | Status | Notes |
|---|---|---|---|
| 17.1 | Submit for Apple App Review | ⬜ | After TestFlight stable |
| 17.2 | Respond to any review feedback | ⬜ | |
| 17.3 | Release | ⬜ | |

---

## Phase 18 — Android Play Store Launch

| # | Task | Status | Notes |
|---|---|---|---|
| 18.1 | Enroll in Google Play Developer account | ⬜ | **One-time $25 USD** (~₱1,400) |
| 18.2 | Build release APK/AAB | ⬜ | `flutter build appbundle --release` |
| 18.3 | Create Play Store listing | ⬜ | |
| 18.4 | Internal testing track first | ⬜ | |
| 18.5 | Release | ⬜ | |

---

## Cost Summary

| Item | Cost | When |
|---|---|---|
| Apple Developer Program | $99/year USD | Before TestFlight |
| Google Play Developer | $25 one-time USD | Before Play Store |
| Firebase (Analytics + Crashlytics) | Free | Phase 9–10 |
| Resend or SendGrid (email) | Free tier | Phase 7 |
| Aseprite (sprite sheets) | ~$20 one-time | Phase 5 |
| Custom domain `potoos.app` | ~$12–20/year | Optional but recommended |
| **Total to launch** | **~$156 USD one-time + $99/year** | |

---

## Already Done ✅

- Potoos rebrand (app name, colors, platform configs, bundle ID)
- Potoos color palette (`midnightBurgundy`, `velvetMaroon`, `brightGold`, etc.)
- `PotoWave` widget — 6-frame looping splash screen animation
- `PotoMascot` widget — 5 static expression states
- Mascot placed on 6 UI locations (splash, empty states, upload, Save All, errors)
- Splash screen dark gradient redesign
- Poto mascot assets: 5 state PNGs, 6 wave frames, character sheet, expression sheet
- iOS entitlements (push notifications, OAuth URL scheme)
- iOS bundle ID `com.potoos.app`, Android `com.potoos.app`
- PWA manifest updated to Potoos
- ZIP fallback filename `potoos-album`
- `flutter analyze` zero issues, all tests passing
- Deployed to GitHub (`akircyno/litratolink` main branch)
