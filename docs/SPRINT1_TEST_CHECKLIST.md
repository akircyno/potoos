# LitratoLink Sprint 1 Test Checklist

Use this checklist when manually verifying the Sprint 1 original-quality flow.

## Core Flow

- Sign in with Google.
- Confirm `user_profiles` has one row for the signed-in user.
- Create a private album.
- Confirm `albums` has the new album.
- Confirm `album_members` has the creator as `admin`.
- Upload one original photo from the album.
- Confirm `storage_objects` has the original file size.
- Confirm `media_files.upload_status` is `completed`.
- Open the uploaded file in the album.
- Download Original.
- Compare the downloaded file size with the original file size.
- Confirm File Preview shows `Original size verified`.

## Invite And Roles

- Open Album Details as an Admin.
- Confirm the members list shows the current user as `ADMIN`.
- Try inviting an email that has not signed in yet.
- Confirm the app shows: `Ask this person to sign in to LitratoLink once before inviting them.`
- Sign in once with a second real account.
- Invite that account as `Viewer`.
- Confirm both accounts can see each member's name/email in the member list.
- Confirm Viewer can open the album and download originals.
- Confirm Viewer cannot upload.
- Change or re-invite the second account as `Contributor`.
- Confirm Contributor can upload.
- Confirm only Admin can invite members.

## Save All

- Upload at least two completed original files.
- Open Album Details.
- Tap Save All.
- Confirm the Save All screen lists the real files from the album.
- Tap Save All Originals.
- Confirm each original downloads through the browser/download picker.
- Confirm progress reaches complete.

## Security Checks

- Sign in as a user who is not an album member.
- Confirm the private album does not appear in the album list.
- Try opening a known album or file route manually.
- Confirm backend returns a blocked or unavailable message.
- Confirm Flutter does not expose service role keys or Google refresh tokens.

## Notes

- Expected live test file so far: `IMG_3778.JPG`.
- The repo should be clean except for local-only tooling such as `awesome-codex-skills`.
- Commit only after a meaningful verified checkpoint.
