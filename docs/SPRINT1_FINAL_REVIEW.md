# LitratoLink Sprint 1 Final Review

Last updated: 2026-05-30

## Current Result

Sprint 1 now supports the core private original-quality flow:

- Google sign-in creates or refreshes a user profile.
- A signed-in user can create a private album.
- The album creator becomes an Admin member.
- Admins and Contributors can upload original files.
- Viewers are blocked from upload in the UI and backend.
- Completed files appear in the album gallery and file list.
- Album, media, and member reads refresh when the signed-in profile changes.
- Original files download through the `download-original-file` Edge Function.
- File Preview displays a downloaded-size vs expected-original-size quality check.
- Save All uses real album files and downloads originals through the same backend path.
- Admins can invite existing LitratoLink users by email and role.
- Admins can update an existing member's role from the same invite form.
- Admins can update another member's role from the member row menu.
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

## Security Review

- Flutter does not use the Supabase service role key.
- Google Drive credentials stay in Supabase Edge Function secrets.
- Downloads are proxied through an Edge Function, so Flutter does not receive Google access tokens.
- Album and media reads rely on RLS membership policies.
- Active album members can read basic profile details for other active, unbanned members in the same album.
- Upload is checked in Edge Functions with Admin/Contributor role logic.
- Download is checked in Edge Functions with active album membership logic.
- Failed upload paths now mark `media_files.upload_status` as `failed`.
- Legacy upload completion verifies final size against original upload metadata.

## Manual Tests Still Needed

- Sign in with a second real account.
- Invite that account as Viewer.
- Confirm Viewer can open/download but cannot upload.
- Invite or update that account as Contributor.
- Confirm Contributor can upload.
- Confirm non-member album/file access is blocked from a second account.
- Test Save All with at least two completed files.
- Compare downloaded file properties in Windows against the original file.

## Known Notes

- `awesome-codex-skills` appears as a modified gitlink in local status and is intentionally not part of app checkpoints.
- Browser upload currently sends original bytes through `upload-original-file` as base64 JSON for Sprint 1 reliability.
- `create-upload-session` prepares metadata and Drive folders, then returns the server-side upload function target instead of creating an unused Google resumable session.
- This is acceptable for the current proof flow, but larger production uploads should return to resumable/direct upload or chunked upload.
