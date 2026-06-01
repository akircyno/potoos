# LitratoLink Codex Project Workflow

Use this file as the short working agreement for future Codex sessions so we do not repeat the same setup and workflow prompts.

## Source Of Truth

- UI reference: `docs/ui-reference/litratolink_mobile_ui.html`
- Product/backend direction: `docs/# LitratoLink Master Product Plan v.md`
- Sprint execution order: `docs/# LitratoLink Sprint 1 Build Prompt.md`
- Manual Sprint 1 QA checklist: `docs/SPRINT1_TEST_CHECKLIST.md`
- Sprint 1 final review/status: `docs/SPRINT1_FINAL_REVIEW.md`
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
- Letter spacing should stay at 0 for readable compact mobile text.
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
- `create-upload-session` prepares DB records and Drive folders for the server-side upload path.
- Original upload works through `upload-original-file`.
- Failed upload paths are marked as `failed` instead of being left as `uploading`.
- Upload progress blocks the Back to Album action while original bytes are still uploading.
- Legacy `complete-upload` also verifies final size against the original upload metadata.
- Download Original works through `download-original-file`.
- Album details show uploaded media and current members.
- Album media rows and File Preview show uploader profile names when visible.
- Album/media/member providers are keyed to the current signed-in profile so role state refreshes after account switching.
- Album Details and Save All stop showing stale content if the current account no longer has active album membership.
- Album members can read basic profile details for other active, unbanned members in shared albums.
- Album `updated_at` is refreshed after successful uploads and member changes so Home, Invites, and Activity stay recent.
- Admin-only invite form validates album admin permission.
- Invite form shows a friendly message when the email has not signed in yet.
- Invite form clears after a successful invite and keeps the email after errors.
- Invite form can update the role of an existing active member.
- Admins can also update another member's role from the member row menu.
- Admins can remove another member from the member row menu after confirmation.
- Invite controller auto-disposes so old invite messages do not leak between album screens.
- Upload and download controllers auto-dispose so progress state resets between files/screens.
- Viewer upload controls are blocked in the Flutter UI.
- Upload completion also re-checks Admin/Contributor permission before accepting original bytes.
- Direct pending media row updates also require current Admin/Contributor access.
- Save All screen uses real album files and downloads originals through `download-original-file`.
- Album Details selection mode lets users select files and save only selected originals.
- Save All fetches album files itself and uses Album Details data only as a fallback.
- Save All shows a retryable error if its file fetch fails with no fallback data.
- Save All creates one ZIP download for browser reliability and disables cancel navigation while active.
- Direct Upload route now explains that uploads must start from an album.
- File Preview shows a tester-friendly downloaded-size vs expected-original-size check.
- Debug quality logs include SHA-256 checksums for selected originals and downloaded originals.
- Download permission/file errors are mapped to friendly app messages instead of raw Dio errors.
- Activity tab is driven by real album data instead of fake placeholder notifications.
- Invites tab is driven by real album data and links Admins to member management.
- Profile tab shows the signed-in account, Google avatar when available, and real album totals.
- Unused Flutter demo album data was removed.
- Test coverage includes role helpers and downloaded-size quality checks.
- Live test file `IMG_3778.JPG` uploaded and downloaded at original size.
- Stale pending test upload rows were cleaned from Supabase.

## Current Pause State

- Invite / album members is implemented and deployed, including add, role update, and member removal.
- Local checks passed:
  - `flutter analyze`
  - `flutter test`
  - `flutter build web --release`
- Verified with an unregistered email:
  - App shows `Ask this person to sign in to LitratoLink once before inviting them.`
- Still useful to test with a second real registered account before expanding roles deeper.
- Still useful to test removing and re-adding a second registered account from the Admin UI.
- Save All is implemented for completed album files, but should be manually tested with more than one file.
- Upload, invite/update/restore member, and remove member Edge Functions now touch the album timestamp after success.

## Next Product Step

Continue the Invite / Album Members feature QA:

1. Admin opens Album Details.
2. App shows member list.
3. Admin enters an existing LitratoLink user email.
4. Admin chooses Admin, Contributor, or Viewer.
5. Edge Function validates admin permission and adds/restores membership.
6. App refreshes members and album counts.
7. Test a second real registered account.
8. Admin removes the second account from the member row menu.
9. Confirm removed account loses album access after refresh/sign-in.
10. Re-add the second account and confirm role-specific access.
11. Manually test Save All with multiple completed files.
