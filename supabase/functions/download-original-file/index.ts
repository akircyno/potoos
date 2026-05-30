import { corsHeaders, handleCors } from "../_shared/cors.ts";
import { error } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { downloadDriveFileBytes } from "../_shared/googleDrive.ts";
import { isAlbumMember } from "../_shared/permissions.ts";
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
    return error("INVALID_REQUEST", "Please send valid download details.", 400);
  }

  if (!isUuid(body.media_file_id)) {
    return error("INVALID_REQUEST", "Please send a valid file ID.", 400);
  }

  const mediaFileId = body.media_file_id;

  const { data: mediaFile, error: mediaError } = await supabaseAdmin
    .from("media_files")
    .select(
      "id, album_id, storage_object_id, original_filename, mime_type, file_size_bytes, upload_status, is_deleted, permanently_deleted_at",
    )
    .eq("id", mediaFileId)
    .maybeSingle();

  if (mediaError) {
    console.error("download-original-file media lookup failed", mediaError.message);
    return error("SERVER_ERROR", "Could not load the file. Please try again.", 500);
  }

  if (
    !mediaFile ||
    mediaFile.upload_status !== "completed" ||
    mediaFile.is_deleted ||
    mediaFile.permanently_deleted_at
  ) {
    return error("FILE_NOT_FOUND", "This file is no longer available.", 404);
  }

  const member = await isAlbumMember(mediaFile.album_id, user.id);
  if (!member) {
    return error("FORBIDDEN", "You do not have permission to download this file.", 403);
  }

  const { data: storageObject, error: storageError } = await supabaseAdmin
    .from("storage_objects")
    .select("id, provider_file_id, file_size_bytes, mime_type, is_deleted")
    .eq("id", mediaFile.storage_object_id)
    .eq("is_deleted", false)
    .maybeSingle();

  if (storageError) {
    console.error("download-original-file storage object lookup failed", storageError.message);
    return error("SERVER_ERROR", "Could not load the stored file. Please try again.", 500);
  }

  if (!storageObject?.provider_file_id) {
    return error("STORAGE_ERROR", "Download access is not ready yet.", 500);
  }

  try {
    const bytes = await downloadDriveFileBytes(storageObject.provider_file_id);
    const expectedSize = storageObject.file_size_bytes ?? mediaFile.file_size_bytes;

    if (expectedSize && bytes.byteLength !== expectedSize) {
      return error("DOWNLOAD_FAILED", "Downloaded file size did not match. Please try again.", 500);
    }

    return new Response(bytes, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": mediaFile.mime_type,
        "Content-Length": String(bytes.byteLength),
        "Content-Disposition": `attachment; filename="${sanitizeHeaderFilename(mediaFile.original_filename)}"`,
        "x-original-filename": encodeURIComponent(mediaFile.original_filename),
        "x-file-size-bytes": String(bytes.byteLength),
        "x-mime-type": mediaFile.mime_type,
      },
    });
  } catch (downloadError) {
    console.error("download-original-file Google Drive download failed", downloadError);
    return error("STORAGE_ERROR", "Could not download from Google Drive. Please try again.", 500);
  }
});

function sanitizeHeaderFilename(value: string) {
  return value.replace(/["\\\r\n]/g, "_");
}
