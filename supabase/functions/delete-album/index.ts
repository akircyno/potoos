import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { isUuid } from "../_shared/validation.ts";
import { deleteDriveItem } from "../_shared/googleDrive.ts";

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

  // Verify caller is admin of this album
  const { data: member, error: memberError } = await supabaseAdmin
    .from("album_members")
    .select("role")
    .eq("album_id", albumId)
    .eq("user_id", user.id)
    .eq("is_active", true)
    .maybeSingle();

  if (memberError) {
    console.error("delete-album member lookup failed", memberError.message);
    return error("SERVER_ERROR", "Could not verify your permissions.", 500);
  }

  if (!member || member.role !== "admin") {
    return error("FORBIDDEN", "Only the album Admin can permanently delete this space.", 403);
  }

  // Get the album's Drive folder ID
  const { data: album, error: albumError } = await supabaseAdmin
    .from("albums")
    .select("id, storage_provider_id")
    .eq("id", albumId)
    .eq("is_deleted", false)
    .maybeSingle();

  if (albumError || !album) {
    return error("NOT_FOUND", "Album not found.", 404);
  }

  const now = new Date().toISOString();

  // 1. Delete the Drive folder (takes all files inside it with it).
  // Non-fatal: if Drive is unavailable or the folder is already gone we still
  // clean up the database records so the album disappears from the app.
  if (album.storage_provider_id) {
    try {
      await deleteDriveItem(album.storage_provider_id);
      console.log("delete-album: Drive folder deleted", album.storage_provider_id);
    } catch (driveErr) {
      console.error("delete-album: Drive deletion failed (continuing with DB cleanup)", driveErr);
    }
  }

  // 2. Mark all media_files as permanently deleted
  const { error: filesError } = await supabaseAdmin
    .from("media_files")
    .update({
      is_deleted: true,
      deleted_at: now,
      permanently_deleted_at: now,
      deleted_by: user.id,
    })
    .eq("album_id", albumId)
    .isFilter("permanently_deleted_at", null);

  if (filesError) {
    console.error("delete-album media_files cleanup failed", filesError.message);
    // Non-fatal — continue with album deletion
  }

  // 3. Deactivate all album members
  const { error: membersError } = await supabaseAdmin
    .from("album_members")
    .update({ is_active: false, removed_at: now })
    .eq("album_id", albumId)
    .eq("is_active", true);

  if (membersError) {
    console.error("delete-album members cleanup failed", membersError.message);
    // Non-fatal — continue
  }

  // 4. Mark the album as deleted
  const { error: albumDeleteError } = await supabaseAdmin
    .from("albums")
    .update({
      is_deleted: true,
      deleted_at: now,
      delete_expires_at: now,
    })
    .eq("id", albumId);

  if (albumDeleteError) {
    console.error("delete-album album update failed", albumDeleteError.message);
    return error("SERVER_ERROR", "Could not complete deletion. Please try again.", 500);
  }

  return success({ album_id: albumId, deleted: true });
});
