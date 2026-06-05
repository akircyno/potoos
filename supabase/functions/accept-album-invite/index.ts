import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { touchAlbum } from "../_shared/albums.ts";
import { isUuid } from "../_shared/validation.ts";

Deno.serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return error("INVALID_REQUEST", "Please send a POST request.", 405);
  }

  const { user, error: authError } = await getUserFromRequest(req);
  if (authError || !user) {
    return error("UNAUTHENTICATED", "Please log in to continue.", 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return error("INVALID_REQUEST", "Please send valid invite details.", 400);
  }

  if (!isUuid(body.invite_id)) {
    return error("INVALID_REQUEST", "Please send a valid invite id.", 400);
  }
  const inviteId = body.invite_id as string;

  // Fetch and validate invite
  const { data: invite, error: inviteError } = await supabaseAdmin
    .from("album_invites")
    .select("id, album_id, invited_user_id, role, status")
    .eq("id", inviteId)
    .maybeSingle();

  if (inviteError) {
    console.error("accept-album-invite invite lookup failed", inviteError.message);
    return error("SERVER_ERROR", "Could not load the invite. Please try again.", 500);
  }
  if (!invite) {
    return error("NOT_FOUND", "Invite not found.", 404);
  }
  if ((invite as Record<string, unknown>).invited_user_id !== user.id) {
    return error("FORBIDDEN", "This invite is not for you.", 403);
  }
  if ((invite as Record<string, unknown>).status !== "pending") {
    return error("INVALID_REQUEST", "This invite has already been responded to.", 409);
  }

  const albumId = (invite as Record<string, unknown>).album_id as string;
  const role = (invite as Record<string, unknown>).role as string;

  // Check for an existing membership row (soft-deleted users need a restore).
  const { data: existingMember } = await supabaseAdmin
    .from("album_members")
    .select("id, is_active")
    .eq("album_id", albumId)
    .eq("user_id", user.id)
    .maybeSingle();

  let member: Record<string, unknown>;

  if (existingMember) {
    if ((existingMember as Record<string, unknown>).is_active) {
      // Edge case: already an active member (e.g. added by another admin meanwhile).
      // Mark invite accepted and return the existing membership.
      await supabaseAdmin
        .from("album_invites")
        .update({ status: "accepted", responded_at: new Date().toISOString() })
        .eq("id", inviteId);
      return success({ action: "already_member" });
    }

    // Restore previously-removed membership.
    const { data: restored, error: restoreError } = await supabaseAdmin
      .from("album_members")
      .update({
        role,
        is_active: true,
        removed_at: null,
        joined_at: new Date().toISOString(),
      })
      .eq("id", (existingMember as Record<string, unknown>).id)
      .select("album_id, user_id, role, joined_at")
      .single();

    if (restoreError || !restored) {
      console.error("accept-album-invite restore failed", restoreError?.message);
      return error("SERVER_ERROR", "Could not join the album. Please try again.", 500);
    }
    member = restored as Record<string, unknown>;
  } else {
    // First-time member: insert new row.
    const { data: inserted, error: insertError } = await supabaseAdmin
      .from("album_members")
      .insert({
        album_id: albumId,
        user_id: user.id,
        role,
        invited_by: (invite as Record<string, unknown>).invited_by_id,
      })
      .select("album_id, user_id, role, joined_at")
      .single();

    if (insertError || !inserted) {
      console.error("accept-album-invite insert failed", insertError?.message);
      return error("SERVER_ERROR", "Could not join the album. Please try again.", 500);
    }
    member = inserted as Record<string, unknown>;
  }

  // Mark invite accepted.
  await supabaseAdmin
    .from("album_invites")
    .update({ status: "accepted", responded_at: new Date().toISOString() })
    .eq("id", inviteId);

  await touchAlbum(albumId);

  return success({ member, action: "accepted" });
});
