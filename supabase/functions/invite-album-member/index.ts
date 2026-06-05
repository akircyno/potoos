import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { AlbumRole, getAlbumRole } from "../_shared/permissions.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { touchAlbum } from "../_shared/albums.ts";
import { isUuid } from "../_shared/validation.ts";
import { sendInviteEmail } from "../_shared/email.ts";

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

  if (!isUuid(body.album_id) || !isValidEmail(body.email) || !isInviteRole(body.role)) {
    return error("INVALID_REQUEST", "Please send a valid email and role.", 400);
  }

  const albumId = body.album_id as string;
  const email = (body.email as string).trim().toLowerCase();
  const role = body.role as AlbumRole;

  const inviterRole = await getAlbumRole(albumId, user.id);
  if (inviterRole !== "admin") {
    return error("FORBIDDEN", "Only album admins can invite people.", 403);
  }

  const { data: inviterProfile } = await supabaseAdmin
    .from("user_profiles")
    .select("display_name")
    .eq("id", user.id)
    .maybeSingle();
  const inviterDisplayName = inviterProfile?.display_name ?? "Someone";

  const { data: album, error: albumError } = await supabaseAdmin
    .from("albums")
    .select("id, name, is_deleted")
    .eq("id", albumId)
    .eq("is_deleted", false)
    .maybeSingle();

  if (albumError) {
    console.error("invite-album-member album lookup failed", albumError.message);
    return error("SERVER_ERROR", "Could not load the album. Please try again.", 500);
  }
  if (!album) {
    return error("ALBUM_NOT_FOUND", "This album is no longer available.", 404);
  }
  const albumName = (album as Record<string, unknown>).name as string ?? "this space";

  const { data: invitedProfile, error: profileError } = await supabaseAdmin
    .from("user_profiles")
    .select("id, email, display_name, is_active, is_banned")
    .eq("email", email)
    .eq("is_active", true)
    .eq("is_banned", false)
    .maybeSingle();

  if (profileError) {
    console.error("invite-album-member profile lookup failed", profileError.message);
    return error("SERVER_ERROR", "Could not find that person. Please try again.", 500);
  }
  if (!invitedProfile) {
    return error("USER_NOT_FOUND", "Ask this person to sign in to Potoos once before inviting them.", 404);
  }
  if (invitedProfile.id === user.id) {
    return error("INVALID_REQUEST", "You are already a member of this album.", 400);
  }

  // ── Existing active membership: update role directly (no re-invite needed) ──
  const { data: existingMember, error: existingError } = await supabaseAdmin
    .from("album_members")
    .select("id, role, is_active")
    .eq("album_id", albumId)
    .eq("user_id", invitedProfile.id)
    .maybeSingle();

  if (existingError) {
    console.error("invite-album-member existing member lookup failed", existingError.message);
    return error("SERVER_ERROR", "Could not check album membership. Please try again.", 500);
  }

  if (existingMember?.is_active) {
    if (existingMember.role === role) {
      return error("ALREADY_EXISTS", "This person is already a member with that role.", 409);
    }

    const { data: updatedMember, error: updateError } = await supabaseAdmin
      .from("album_members")
      .update({ role, invited_by: user.id })
      .eq("id", existingMember.id)
      .select(
        "album_id, user_id, role, joined_at, profile:user_profiles!album_members_user_id_fkey(email, display_name, avatar_url)",
      )
      .single();

    if (updateError || !updatedMember) {
      console.error("invite-album-member role update failed", updateError?.message);
      return error("SERVER_ERROR", "Could not update this member. Please try again.", 500);
    }

    await touchAlbum(albumId);
    sendInviteEmail({ to: email, inviterName: inviterDisplayName, albumName, role }).catch(() => {});
    return success({ member: mapMember(updatedMember), action: "updated" });
  }

  // ── Check for an already-pending invite ──────────────────────────────────
  const { data: existingInvite } = await supabaseAdmin
    .from("album_invites")
    .select("id")
    .eq("album_id", albumId)
    .eq("invited_user_id", invitedProfile.id)
    .eq("status", "pending")
    .maybeSingle();

  if (existingInvite) {
    return error("ALREADY_EXISTS", "An invite is already pending for this person.", 409);
  }

  // ── Create pending invite (new or previously-removed user) ───────────────
  const { data: invite, error: inviteError } = await supabaseAdmin
    .from("album_invites")
    .insert({
      album_id: albumId,
      invited_user_id: invitedProfile.id,
      invited_by_id: user.id,
      invited_by_name: inviterDisplayName,
      album_name: albumName,
      role,
      status: "pending",
    })
    .select("id, album_id, invited_user_id, role, status, created_at")
    .single();

  if (inviteError || !invite) {
    console.error("invite-album-member invite insert failed", inviteError?.message);
    return error("SERVER_ERROR", "Could not send the invite. Please try again.", 500);
  }

  await touchAlbum(albumId);
  sendInviteEmail({
    to: email,
    inviterName: inviterDisplayName,
    albumName,
    role,
    inviteId: (invite as Record<string, unknown>).id as string,
  }).catch(() => {});

  return success({ invite, action: "invited" }, 201);
});

function isValidEmail(value: unknown): value is string {
  if (typeof value !== "string") return false;
  const trimmed = value.trim();
  return trimmed.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed);
}

// Admin role is excluded from the invite flow — assign admin via role-change
// on an existing member.
function isInviteRole(value: unknown): value is AlbumRole {
  return value === "contributor" || value === "viewer";
}

function mapMember(row: Record<string, unknown>) {
  const profile = Array.isArray(row.profile) ? row.profile[0] : row.profile;
  return {
    album_id: row.album_id,
    user_id: row.user_id,
    role: row.role,
    joined_at: row.joined_at,
    email: readProfileText(profile, "email"),
    display_name: readProfileText(profile, "display_name"),
    avatar_url: readProfileText(profile, "avatar_url"),
  };
}

function readProfileText(profile: unknown, key: string) {
  if (!profile || typeof profile !== "object") return null;
  const value = (profile as Record<string, unknown>)[key];
  return typeof value === "string" ? value : null;
}
