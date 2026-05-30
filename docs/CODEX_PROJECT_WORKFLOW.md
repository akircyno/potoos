# LitratoLink Codex Project Workflow

Use this file as the short working agreement for future Codex sessions so we do not repeat the same setup and workflow prompts.

## Source Of Truth

- UI reference: `docs/ui-reference/litratolink_mobile_ui.html`
- Product/backend direction: `docs/# LitratoLink Master Product Plan v.md`
- Sprint execution order: `docs/# LitratoLink Sprint 1 Build Prompt.md`
- Manual Sprint 1 QA checklist: `docs/SPRINT1_TEST_CHECKLIST.md`
- Do not redesign the UI unless explicitly requested.
- Flutter screens should closely match the HTML mockup layout, navigation, colors, component hierarchy, and user flow.

## Design System

- Colors:
  - Deep Maroon `#4A1220`
  - Maroon `#6B1C2E`
  - Soft Gold `#C4973A`
  - Warm Cream `#FAF6F0`
- Fonts:
  - Headings: General Sans
  - Body/UI: Inter
- Core components:
  - Album Card
  - Gallery Grid
  - Role Chips: Admin, Contributor, Viewer
  - Progress bars
  - Save All ring
  - Invite Form
  - Notification items

## Engineering Workflow

- Read local code/docs before changing implementation.
- Use Context7 for current docs when working with libraries, SDKs, APIs, CLIs, or cloud services.
- Use `rg` for searching.
- Use `apply_patch` for manual edits.
- Run focused checks after meaningful changes:
  - `flutter analyze`
  - `flutter test`
  - `flutter build web --release`
- Start/restart local preview when needed:
  - `cd C:\dev\LitratoLink\app`
  - `py -m http.server 8080 --directory build\web`
- Local preview URL:
  - `http://localhost:8080`

## Git Workflow

- Main repo path: `C:\dev\LitratoLink`
- `app/` is now tracked as a normal folder in the root repo.
- Do not commit from `C:\dev\LitratoLink\app`.
- Use only the root repo:
  - `cd C:\dev\LitratoLink`
  - `git add ...`
  - `git commit -m "..."`
  - `git push origin main`
- Commit only meaningful checkpoints:
  - feature completed and verified
  - bug fixed and verified
  - Supabase/schema/function work is stable
  - working flow confirmed in the app
  - before risky changes or a major task switch
- Do not commit tiny edits, experiments, failed attempts, or local-only cleanup.
- Keep local tool/cache folders out of commits, especially:
  - `awesome-codex-skills`
  - `supabase/.temp/`

## Secrets And Safety

- Never commit service role keys, Google client secrets, refresh tokens, or real `.env`.
- Flutter may contain only client-safe Supabase URL and publishable/anon key in local ignored `app/.env`.
- Service role and Google Drive credentials belong only in Supabase Edge Function secrets.
- Do not repeat secrets in responses.

## Supabase And Google Drive

- Supabase project URL:
  - `https://srquwfxaknsoiuvmlrxy.supabase.co`
- Google Drive root folder is configured in Edge Function secrets.
- Current safer storage pattern:
  - Flutter sends original bytes to Edge Function.
  - Edge Function uploads/downloads with Google Drive server-side.
  - Flutter does not receive Google access tokens.

## Verified Sprint 1 Flows

- Google login creates `user_profiles`.
- Profile creation normalizes email casing and refreshes `last_active_at`.
- Album creation creates `albums` and admin `album_members`.
- Original upload works through `upload-original-file`.
- Failed upload paths are marked as `failed` instead of being left as `uploading`.
- Legacy `complete-upload` also verifies final size against the original upload metadata.
- Download Original works through `download-original-file`.
- Album details show uploaded media and current members.
- Admin-only invite form validates album admin permission.
- Invite form shows a friendly message when the email has not signed in yet.
- Viewer upload controls are blocked in the Flutter UI.
- Save All screen uses real album files and downloads originals through `download-original-file`.
- File Preview shows a tester-friendly downloaded-size vs expected-original-size check.
- Download permission/file errors are mapped to friendly app messages instead of raw Dio errors.
- Activity tab is driven by real album data instead of fake placeholder notifications.
- Unused Flutter demo album data was removed.
- Test coverage includes role helpers and downloaded-size quality checks.
- Live test file `IMG_3778.JPG` uploaded and downloaded at original size.
- Stale pending test upload rows were cleaned from Supabase.

## Current Pause State

- Invite / album members is implemented and deployed.
- Local checks passed:
  - `flutter analyze`
  - `flutter test`
  - `flutter build web --release`
- Verified with an unregistered email:
  - App shows `Ask this person to sign in to LitratoLink once before inviting them.`
- Still useful to test with a second real registered account before expanding roles deeper.
- Save All is implemented for completed album files, but should be manually tested with more than one file.

## Next Product Step

Continue the Invite / Album Members feature:

1. Admin opens Album Details.
2. App shows member list.
3. Admin enters an existing LitratoLink user email.
4. Admin chooses Admin, Contributor, or Viewer.
5. Edge Function validates admin permission and adds/restores membership.
6. App refreshes members and album counts.
7. Test a second real registered account.
8. Confirm role-specific access in later prompts.
9. Manually test Save All with multiple completed files.
