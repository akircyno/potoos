# LitratoLink Sprint 1 Final Review

Last updated: 2026-06-01

## Current Result

Sprint 1 now supports the core private original-quality flow:

- Google sign-in creates or refreshes a user profile.
- A signed-in user can create a private album.
- The album creator becomes an Admin member.
- Admins and Contributors can upload original files.
- Viewers are blocked from upload in the UI and backend.
- Upload completion re-checks Admin/Contributor permission before accepting original bytes.
- Completed files appear in the album gallery and file list.
- File metadata uses joined uploader profile names when visible.
- Album, media, and member reads refresh when the signed-in profile changes.
- Album Details and Save All stop showing stale content if membership is removed.
- Album timestamps refresh after successful uploads and member changes.
- Original files download through the `download-original-file` Edge Function.
- File Preview displays a downloaded-size vs expected-original-size quality check.
- Debug quality logs include SHA-256 checksums for upload and download comparison.
- Upload progress keeps users on the upload screen until the active upload finishes or fails.
- Save All uses real album files and downloads originals through the same backend path.
- Album Details supports selecting files before Save All.
- Save All bundles originals into one ZIP for browser downloads and keeps the batch screen stable while active.
- Invites tab uses real album data and links Admins to member management.
- Profile tab uses the signed-in account and real album totals instead of placeholder content.
- Admins can invite existing LitratoLink users by email and role.
- Admins can update an existing member's role from the same invite form.
- Admins can update another member's role from the member row menu.
- Admins can remove another member from the member row menu after confirmation.
- Unregistered invite emails show a friendly action message.

## Verified Locally

- `flutter analyze`
- `flutter test`
- `flutter build web --release`
- Local preview responds at `http://localhost:8080`

## Verified Live

- Supabase project is connected.
- Google login works.
- `user_profiles` row is created.
- Album creation works.
- Upload original works through server-side Google Drive upload.
- Download original works through server-side Google Drive proxy.
- Test file `IMG_3778.JPG` uploaded and downloaded with matching size.
- Invite form correctly handles an unregistered email.

## Deployed Edge Functions

- `create-user-profile`
- `create-album`
- `test-google-drive-connection`
- `create-upload-session`
- `complete-upload`
- `upload-original-file`
- `download-original-file`
- `invite-album-member`
- `remove-album-member`

## Security Review

- Flutter does not use the Supabase service role key.
- Google Drive credentials stay in Supabase Edge Function secrets.
- Downloads are proxied through an Edge Function, so Flutter does not receive Google access tokens.
- Album and media reads rely on RLS membership policies.
- Active album members can read basic profile details for other active, unbanned members in the same album.
- Upload is checked in Edge Functions with Admin/Contributor role logic.
- Pending upload completion is rejected if the uploader no longer has Admin/Contributor access.
- Direct pending media row updates also require current Admin/Contributor access.
- Download is checked in Edge Functions with active album membership logic.
- Failed upload paths now mark `media_files.upload_status` as `failed`.
- Legacy upload completion verifies final size against original upload metadata.

## Manual Tests Still Needed

- Sign in with a second real account.
- Invite that account as Viewer.
- Confirm Viewer can open/download but cannot upload.
- Invite or update that account as Contributor.
- Confirm Contributor can upload.
- Remove the second account from the Admin UI.
- Confirm the removed account loses album access after refresh/sign-in.
- Re-add the second account and confirm access returns.
- Confirm non-member album/file access is blocked from a second account.
- Test Save All with at least two completed files.
- Confirm Save All creates one `*-originals.zip` in the browser downloads.
- Compare downloaded file properties in Windows against the original file.

## Known Notes

- `awesome-codex-skills` appears as a modified gitlink in local status and is intentionally not part of app checkpoints.
- Browser upload currently sends original bytes through `upload-original-file` as base64 JSON for Sprint 1 reliability.
- `create-upload-session` prepares metadata and Drive folders, then returns the server-side upload function target instead of creating an unused Google resumable session.
- This is acceptable for the current proof flow, but larger production uploads should return to resumable/direct upload or chunked upload.
