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

  if (!isUuid(body.album_id) || !isValidEmail(body.email) || !isAlbumRole(body.role)) {
    return error("INVALID_REQUEST", "Please send a valid email and role.", 400);
  }

  const albumId = body.album_id;
  const email = body.email.trim().toLowerCase();
  const role = body.role;

  const inviterRole = await getAlbumRole(albumId, user.id);
  if (inviterRole !== "admin") {
    return error("FORBIDDEN", "Only album admins can invite people.", 403);
  }

  // Fetch inviter display name for email (best-effort)
  const { data: inviterProfile } = await supabaseAdmin
    .from("user_profiles")
    .select("display_name")
    .eq("user_id", user.id)
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
    .select("id, email, display_name, avatar_url, is_active, is_banned")
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
      return error("ALREADY_EXISTS", "This person already has that role.", 409);
    }

    const { data: updatedMember, error: updateError } = await supabaseAdmin
      .from("album_members")
      .update({
        role,
        invited_by: user.id,
      })
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
    // Fire-and-forget — invite succeeds even if email fails
    sendInviteEmail({ to: email, inviterName: inviterDisplayName, albumName: albumName, role }).catch(() => {});

    return success({ member: mapMember(updatedMember), action: "updated" });
  }

  if (existingMember) {
    const { data: restoredMember, error: restoreError } = await supabaseAdmin
      .from("album_members")
      .update({
        role,
        invited_by: user.id,
        joined_at: new Date().toISOString(),
        removed_at: null,
        is_active: true,
      })
      .eq("id", existingMember.id)
      .select(
        "album_id, user_id, role, joined_at, profile:user_profiles!album_members_user_id_fkey(email, display_name, avatar_url)",
      )
      .single();

    if (restoreError || !restoredMember) {
      console.error("invite-album-member restore failed", restoreError?.message);
      return error("SERVER_ERROR", "Could not invite this person. Please try again.", 500);
    }

    await touchAlbum(albumId);
    sendInviteEmail({ to: email, inviterName: inviterDisplayName, albumName: albumName, role }).catch(() => {});

    return success({ member: mapMember(restoredMember), action: "restored" });
  }

  const { data: member, error: memberError } = await supabaseAdmin
    .from("album_members")
    .insert({
      album_id: albumId,
      user_id: invitedProfile.id,
      role,
      invited_by: user.id,
    })
    .select(
      "album_id, user_id, role, joined_at, profile:user_profiles!album_members_user_id_fkey(email, display_name, avatar_url)",
    )
    .single();

  if (memberError || !member) {
    console.error("invite-album-member insert failed", memberError?.message);
    return error("SERVER_ERROR", "Could not invite this person. Please try again.", 500);
  }

  await touchAlbum(albumId);
  sendInviteEmail({ to: email, inviterName: inviterDisplayName, albumName: albumName, role }).catch(() => {});

  return success({ member: mapMember(member), action: "added" }, 201);
});

function isValidEmail(value: unknown): value is string {
  if (typeof value !== "string") return false;
  const trimmed = value.trim();
  return trimmed.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed);
}

function isAlbumRole(value: unknown): value is AlbumRole {
  return value === "admin" || value === "contributor" || value === "viewer";
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
