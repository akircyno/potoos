import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
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
    return error("INVALID_REQUEST", "Please send a valid request body.", 400);
  }

  if (!isUuid(body.album_id)) {
    return error("INVALID_REQUEST", "Please send a valid album ID.", 400);
  }

  const albumId = body.album_id as string;
  // archive=true (default) archives; archive=false unarchives
  const shouldArchive = body.archive !== false;

  const { data: member, error: memberError } = await supabaseAdmin
    .from("album_members")
    .select("role")
    .eq("album_id", albumId)
    .eq("user_id", user.id)
    .eq("is_active", true)
    .maybeSingle();

  if (memberError) {
    console.error("archive-album member lookup failed", memberError.message);
    return error("SERVER_ERROR", "Could not verify your permissions.", 500);
  }

  if (!member || member.role !== "admin") {
    return error(
      "FORBIDDEN",
      "Only the album Admin can archive or restore this space.",
      403,
    );
  }

  const { error: updateError } = await supabaseAdmin
    .from("albums")
    .update({ is_archived: shouldArchive, updated_at: new Date().toISOString() })
    .eq("id", albumId)
    .eq("is_deleted", false);

  if (updateError) {
    console.error("archive-album update failed", updateError.message);
    return error(
      "SERVER_ERROR",
      `Could not ${shouldArchive ? "archive" : "restore"} the album. Please try again.`,
      500,
    );
  }

  return success({ album_id: albumId, archived: shouldArchive });
});
