import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { getAlbumRole } from "../_shared/permissions.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { touchAlbum } from "../_shared/albums.ts";
import { logActivity } from "../_shared/activity.ts";
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
    return error("INVALID_REQUEST", "Please send valid member details.", 400);
  }

  if (!isUuid(body.album_id) || !isUuid(body.user_id)) {
    return error("INVALID_REQUEST", "Please send valid member details.", 400);
  }

  const albumId = body.album_id;
  const targetUserId = body.user_id;

  if (targetUserId === user.id) {
    return error("INVALID_REQUEST", "You cannot remove yourself from the album.", 400);
  }

  const requesterRole = await getAlbumRole(albumId, user.id);
  if (requesterRole !== "admin") {
    return error("FORBIDDEN", "Only album admins can remove members.", 403);
  }

  const { data: member, error: memberError } = await supabaseAdmin
    .from("album_members")
    .select("id, role, is_active")
    .eq("album_id", albumId)
    .eq("user_id", targetUserId)
    .eq("is_active", true)
    .maybeSingle();

  if (memberError) {
    console.error("remove-album-member lookup failed", memberError.message);
    return error("SERVER_ERROR", "Could not load this member. Please try again.", 500);
  }

  if (!member) {
    return error("MEMBER_NOT_FOUND", "This person is not an active member.", 404);
  }

  if (member.role === "admin") {
    const { data: otherAdmin, error: adminError } = await supabaseAdmin
      .from("album_members")
      .select("id")
      .eq("album_id", albumId)
      .eq("role", "admin")
      .eq("is_active", true)
      .neq("user_id", targetUserId)
      .limit(1)
      .maybeSingle();

    if (adminError) {
      console.error("remove-album-member admin lookup failed", adminError.message);
      return error("SERVER_ERROR", "Could not check album admins. Please try again.", 500);
    }

    if (!otherAdmin) {
      return error("INVALID_REQUEST", "An album needs at least one Admin.", 400);
    }
  }

  const { error: updateError } = await supabaseAdmin
    .from("album_members")
    .update({
      is_active: false,
      removed_at: new Date().toISOString(),
    })
    .eq("id", member.id);

  if (updateError) {
    console.error("remove-album-member update failed", updateError.message);
    return error("SERVER_ERROR", "Could not remove this member. Please try again.", 500);
  }

  await touchAlbum(albumId);

  const { data: removedProfile } = await supabaseAdmin
    .from("user_profiles")
    .select("display_name")
    .eq("id", targetUserId)
    .maybeSingle();

  await logActivity(albumId as string, user.id, "member_left", {
    removed_user_id: targetUserId,
    removed_display_name: (removedProfile as Record<string, unknown> | null)?.display_name ?? null,
  });

  return success({
    album_id: albumId,
    user_id: targetUserId,
  });
});
