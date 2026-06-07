import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { touchAlbum } from "../_shared/albums.ts";
import { isUuid } from "../_shared/validation.ts";
import { deleteDriveItem } from "../_shared/googleDrive.ts";

const MAX_FILE_IDS = 100;

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

  const fileIds = body.file_ids;

  if (
    !isUuid(body.album_id) ||
    !Array.isArray(fileIds) ||
    fileIds.length === 0 ||
    fileIds.length > MAX_FILE_IDS ||
    !fileIds.every(isUuid)
  ) {
    return error("INVALID_REQUEST", "Please send a valid album ID and file IDs.", 400);
  }

  const albumId = body.album_id as string;
  const requestedIds = fileIds as string[];

  // Verify caller is an Admin or Contributor of this album
  const { data: member, error: memberError } = await supabaseAdmin
    .from("album_members")
    .select("role")
    .eq("album_id", albumId)
    .eq("user_id", user.id)
    .eq("is_active", true)
    .maybeSingle();

  if (memberError) {
    console.error("delete-media-files member lookup failed", memberError.message);
    return error("SERVER_ERROR", "Could not verify your permissions.", 500);
  }

  if (!member || (member.role !== "admin" && member.role !== "contributor")) {
    return error("FORBIDDEN", "Only Admins and Contributors can remove files from this album.", 403);
  }

  // Load the requested files (scoped to this album, not already deleted) along
  // with their Drive item IDs via the linked storage object.
  const { data: files, error: filesLookupError } = await supabaseAdmin
    .from("media_files")
    .select("id, storage_object:storage_objects(provider_file_id)")
    .eq("album_id", albumId)
    .eq("is_deleted", false)
    .in("id", requestedIds);

  if (filesLookupError) {
    console.error("delete-media-files lookup failed", filesLookupError.message);
    return error("SERVER_ERROR", "Could not load the selected files. Please try again.", 500);
  }

  const foundFiles = (files ?? []) as Array<{
    id: string;
    storage_object: { provider_file_id: string | null } | { provider_file_id: string | null }[] | null;
  }>;

  const foundIds = new Set(foundFiles.map((file) => file.id));
  const failedIds = requestedIds.filter((id) => !foundIds.has(id));

  if (foundFiles.length === 0) {
    return success({ album_id: albumId, deleted_ids: [], failed_ids: failedIds });
  }

  // Delete each file's Drive item. Non-fatal: if Drive is unavailable or the
  // item is already gone we still clean up the database record.
  for (const file of foundFiles) {
    const storageObject = Array.isArray(file.storage_object)
      ? file.storage_object[0]
      : file.storage_object;
    const providerFileId = storageObject?.provider_file_id;

    if (providerFileId) {
      try {
        await deleteDriveItem(providerFileId);
      } catch (driveErr) {
        console.error(`delete-media-files: Drive deletion failed for ${file.id} (continuing)`, driveErr);
      }
    }
  }

  const now = new Date().toISOString();
  const foundIdsList = Array.from(foundIds);

  const { data: updatedRows, error: updateError } = await supabaseAdmin
    .from("media_files")
    .update({
      is_deleted: true,
      deleted_at: now,
      permanently_deleted_at: now,
      deleted_by: user.id,
    })
    .in("id", foundIdsList)
    .eq("is_deleted", false)
    .select("id");

  if (updateError) {
    console.error("delete-media-files update failed", updateError.message);
    return error("SERVER_ERROR", "Could not remove the selected files. Please try again.", 500);
  }

  const deletedIds = (updatedRows ?? []).map((row) => (row as { id: string }).id);
  const deletedSet = new Set(deletedIds);
  const allFailedIds = [...failedIds, ...foundIdsList.filter((id) => !deletedSet.has(id))];

  if (deletedIds.length > 0) {
    await touchAlbum(albumId);
  }

  return success({
    album_id: albumId,
    deleted_ids: deletedIds,
    failed_ids: allFailedIds,
  });
});
