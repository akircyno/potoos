import { corsHeaders, handleCors } from "../_shared/cors.ts";
import { error } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { downloadDriveThumbnailBytes } from "../_shared/googleDrive.ts";
import { isAlbumMember } from "../_shared/permissions.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { isUuid } from "../_shared/validation.ts";

Deno.serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "GET") {
    return error("INVALID_REQUEST", "Please send a GET request.", 405);
  }

  const { user, error: authError } = await getUserFromRequest(req);
  if (authError || !user) {
    return error("UNAUTHENTICATED", "Please log in to continue.", 401);
  }

  const mediaFileId = new URL(req.url).searchParams.get("media_file_id");
  if (!isUuid(mediaFileId)) {
    return error("INVALID_REQUEST", "Please send a valid file id.", 400);
  }

  const { data: mediaFile, error: mediaError } = await supabaseAdmin
    .from("media_files")
    .select("id, album_id, storage_object_id, upload_status, is_deleted, permanently_deleted_at")
    .eq("id", mediaFileId)
    .maybeSingle();

  if (mediaError) {
    console.error("get-media-preview media lookup failed", mediaError.message);
    return error("SERVER_ERROR", "Could not load the preview. Please try again.", 500);
  }

  if (
    !mediaFile ||
    mediaFile.upload_status !== "completed" ||
    mediaFile.is_deleted ||
    mediaFile.permanently_deleted_at
  ) {
    return error("FILE_NOT_FOUND", "Preview is not available.", 404);
  }

  const member = await isAlbumMember(mediaFile.album_id, user.id);
  if (!member) {
    return error("FORBIDDEN", "You do not have permission to preview this file.", 403);
  }

  const { data: storageObject, error: storageError } = await supabaseAdmin
    .from("storage_objects")
    .select("provider_file_id")
    .eq("id", mediaFile.storage_object_id)
    .eq("is_deleted", false)
    .maybeSingle();

  if (storageError) {
    console.error("get-media-preview storage lookup failed", storageError.message);
    return error("SERVER_ERROR", "Could not load the preview. Please try again.", 500);
  }

  if (!storageObject?.provider_file_id) {
    return error("FILE_NOT_FOUND", "Preview is not ready yet.", 404);
  }

  try {
    const preview = await downloadDriveThumbnailBytes(storageObject.provider_file_id);
    if (!preview) {
      return error("FILE_NOT_FOUND", "Preview is not ready yet.", 404);
    }

    if (preview.thumbnailLink) {
      await supabaseAdmin
        .from("media_files")
        .update({ thumbnail_url: preview.thumbnailLink })
        .eq("id", mediaFileId);
    }

    return new Response(preview.bytes, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": preview.mimeType,
        "Content-Length": preview.bytes.byteLength.toString(),
        "Cache-Control": "private, max-age=1800",
      },
    });
  } catch (previewError) {
    console.error("get-media-preview thumbnail fetch failed", previewError);
    return error("STORAGE_ERROR", "Could not load the preview. Please try again.", 502);
  }
});
