# Claude Code Pro Handoff

Last updated: 2026-06-02

This is the practical handoff for continuing LitratoLink development in Claude Code Pro.

## Project Snapshot

LitratoLink is a Flutter Web PWA for private, invite-only photo/video albums with original-quality upload and download.

Current public beta URL:

```text
https://akircyno.github.io/litratolink/
```

Current working app name: **LitratoLink**

Planned future brand: **Potoos**

Mascot: **Poto**

Tagline: **Original memories, safely shared.**

Do **not** rename the app yet. The Potoos rename should happen later as one clean migration after PWA/Sprint 1 QA is stable.

## Repo And App Paths

Root repo:

```text
C:\dev\LitratoLink
```

Flutter app:

```text
C:\dev\LitratoLink\app
```

Important docs:

```text
docs/CODEX_PROJECT_WORKFLOW.md
docs/APP_REVIEWER_BRIEF.md
docs/PWA_BETA_ACCESS.md
docs/SPRINT1_FINAL_REVIEW.md
docs/SPRINT1_TEST_CHECKLIST.md
docs/potoos-brand/README.md
```

UI source of truth:

```text
docs/ui-reference/litratolink_mobile_ui.html
```

Do not redesign the UI unless explicitly requested. Match the HTML mockup's layout, navigation, colors, hierarchy, and flow.

## Current Stack

- Flutter Web PWA
- Supabase Auth with Google login
- Supabase Postgres with RLS
- Supabase Edge Functions for protected backend actions
- Google Drive API for original file storage
- GitHub Pages deployment through GitHub Actions

## Current Design System

Colors:

```text
Deep Maroon #4A1220
Maroon #6B1C2E
Soft Gold #C4973A
Warm Cream #FAF6F0
```

Fonts:

```text
Headings: General Sans
Body/UI: Inter
```

Core components:

- Album Card
- Gallery Grid
- Role Chips: Admin, Contributor, Viewer
- Progress bars
- Save All ring
- Invite Form
- Notification items

## Important Safety Rules

- Never commit service role keys, Google client secrets, refresh tokens, or real `.env` files.
- Flutter may only use client-safe Supabase URL and anon/publishable key.
- Service role and Google Drive credentials belong only in Supabase Edge Function secrets.
- Ignore unrelated local tool/skill folders unless the user asks about them.
- Commit only meaningful progress.
- Commit from the root repo, not from `app/`.

Root git workflow:

```powershell
cd C:\dev\LitratoLink
git status --short
git add <specific files only>
git commit -m "<message>"
git push origin main
```

## Current Known Dirty Worktree

At the time this handoff was written, the worktree had local tool/agent files that should not be assumed to be app work:

```text
skills-lock.json
.agents/skills/...
.claude/
awesome-codex-skills
```

Do not stage or remove these unless the user explicitly asks.

## Verified Sprint 1 Functionality

Already implemented and verified locally:

- Google login creates/refreshes `user_profiles`.
- Web OAuth sends explicit app-root redirect URL for localhost and GitHub Pages.
- Login screen redirects to Home once the user profile becomes available.
- Auth profile load errors after OAuth events are surfaced.
- Album creation works.
- Creator becomes Admin.
- Admin and Contributor can upload.
- Viewer upload is blocked in UI and backend.
- Original upload works through `upload-original-file`.
- Failed upload rows are marked `failed`.
- Original download works through `download-original-file`.
- File Preview shows downloaded-size vs expected-original-size check.
- Debug logs include SHA-256 checksums for upload/download comparison.
- Save All uses real album files and downloads originals through backend.
- Save All creates one ZIP for browser reliability.
- Album details show media and current members.
- Admin can invite an existing signed-in user by email and role.
- Admin can update member role.
- Admin can remove another member.
- Database prevents downgrading/removing the final active Admin.
- Activity, Invites, and Profile tabs use real album data.
- Direct Upload and File Preview route fallback states link back to Albums.

Latest checks passed before handoff:

```text
flutter test
flutter analyze
flutter build web --release
```

The web build still prints a non-blocking Flutter icon-font warning about `CupertinoIcons`; current code search did not find app usage of `CupertinoIcons`.

## Latest Development Commits To Know

Recent important commits:

```text
0980bf4 Fix web OAuth redirect target
80ba478 Improve PWA login return handling
ccb1a2f Add PWA route recovery actions
30ac649 Surface auth profile load errors
```

GitHub Pages deploys from `main` through `.github/workflows/pwa-beta.yml`.

## Manual Setup Still Needed

The user still needs to confirm Supabase Auth URL Configuration is updated.

Supabase Auth URL Configuration:

```text
Site URL:
https://akircyno.github.io/litratolink/

Redirect URLs:
http://localhost:8080/**
https://akircyno.github.io/litratolink/**
```

Google OAuth client should include:

```text
Authorized JavaScript origins:
http://localhost:8080
https://akircyno.github.io
https://srquwfxaknsoiuvmlrxy.supabase.co

Authorized redirect URIs:
https://srquwfxaknsoiuvmlrxy.supabase.co/auth/v1/callback
```

Do not rename GitHub repo, Supabase project, OAuth app, or storage email yet unless the user explicitly starts the Potoos migration.

## Next Development Step

Continue **live PWA QA** after the Supabase Auth URLs are added.

Priority manual QA:

1. Open `https://akircyno.github.io/litratolink/`.
2. Sign in with Google on the hosted PWA.
3. Confirm it returns to Home, not stuck on Login.
4. Create/open an album.
5. Upload an original file.
6. Download original and compare Windows file size to the source file.
7. Upload at least two files.
8. Use Save All and confirm one `*-originals.zip` downloads.
9. Sign in with a second registered account.
10. Invite second account as Viewer.
11. Confirm Viewer can view/download but cannot upload.
12. Update second account to Contributor.
13. Confirm Contributor can upload.
14. Remove second account from Admin UI.
15. Confirm removed account loses album access after refresh/sign-in.
16. Re-add second account and confirm access returns.

## Likely Next Code Work If QA Finds Issues

Focus areas:

- Hosted OAuth redirect/session edge cases
- Browser download behavior on Chrome/mobile
- Save All ZIP filename/path behavior
- Role refresh after account switching
- Route refresh behavior on GitHub Pages hash routes
- Friendly error copy for Edge Function failures

Avoid:

- Rebranding to Potoos too early
- Large upload architecture refactor before Sprint 1 QA closes
- UI redesign
- Moving away from server-side Google Drive handling without a plan

## Potoos Brand Planning

Potoos planning docs exist, but they are not implementation instructions yet:

```text
docs/potoos-brand/README.md
docs/potoos-brand/brand-identity-handoff.md
docs/potoos-brand/mascot-reference-prompts.md
docs/potoos-brand/short-video-animation-plan.md
docs/potoos-brand/capcut-production-role.md
docs/potoos-brand/sprite-sheet-plan.md
```

Potoos locked direction:

```text
Product: Potoos
Mascot: Poto
Tagline: Original memories, safely shared.
Mascot role: Your memory guardian.
```

Rename later in one migration:

1. Finalize mascot reference and app icon.
2. Update app display name, PWA manifest, browser title, and UI copy.
3. Update GitHub Pages URL/base href only if repo is renamed.
4. Update Supabase redirect URLs and Google OAuth origins after URL changes.
5. Re-test OAuth, albums, upload, download, Save All, invites, and route refresh.

## How To Start A Claude Session

Suggested first prompt to Claude Code Pro:

```text
Read docs/CLAUDE_CODE_HANDOFF.md and docs/CODEX_PROJECT_WORKFLOW.md first.
Do not redesign the UI and do not start the Potoos rename yet.
Continue from the live PWA beta QA step. If I report a failing test, inspect the Flutter app and fix only the relevant issue.
Never commit secrets or unrelated local tool files.
```

## Commands For Claude

Run from Flutter app folder:

```powershell
cd C:\dev\LitratoLink\app
flutter test
flutter analyze
flutter build web --release
```

Preview locally:

```powershell
cd C:\dev\LitratoLink\app
flutter build web --release
py -m http.server 8080 --directory build\web
```

Open:

```text
http://localhost:8080
```

## Final Reminder

The current highest-value work is not new features. It is proving the live PWA beta with real hosted OAuth, real second-account roles, original download quality, and Save All ZIP behavior.
