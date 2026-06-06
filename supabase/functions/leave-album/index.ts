import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
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
    return error("INVALID_REQUEST", "Please send valid album details.", 400);
  }

  if (!isUuid(body.album_id)) {
    return error("INVALID_REQUEST", "Please send a valid album ID.", 400);
  }

  const albumId = body.album_id;

  const { data: member, error: memberError } = await supabaseAdmin
    .from("album_members")
    .select("id, role, is_active")
    .eq("album_id", albumId)
    .eq("user_id", user.id)
    .eq("is_active", true)
    .maybeSingle();

  if (memberError) {
    console.error("leave-album member lookup failed", memberError.message);
    return error("SERVER_ERROR", "Could not check your membership. Please try again.", 500);
  }

  if (!member) {
    return error("MEMBER_NOT_FOUND", "You are not an active member of this album.", 404);
  }

  if (member.role === "admin") {
    const { data: otherAdmin, error: adminError } = await supabaseAdmin
      .from("album_members")
      .select("id")
      .eq("album_id", albumId)
      .eq("role", "admin")
      .eq("is_active", true)
      .neq("user_id", user.id)
      .limit(1)
      .maybeSingle();

    if (adminError) {
      console.error("leave-album admin check failed", adminError.message);
      return error("SERVER_ERROR", "Could not check album admins. Please try again.", 500);
    }

    if (!otherAdmin) {
      return error(
        "INVALID_REQUEST",
        "You are the only Admin. Assign another Admin before leaving.",
        400,
      );
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
    console.error("leave-album update failed", updateError.message);
    return error("SERVER_ERROR", "Could not leave the album. Please try again.", 500);
  }

  await touchAlbum(albumId);
  await logActivity(albumId as string, user.id, "member_left", { self_leave: true });

  return success({ album_id: albumId });
});
