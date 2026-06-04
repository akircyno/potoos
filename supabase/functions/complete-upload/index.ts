import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { getDriveFileMetadata } from "../_shared/googleDrive.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { touchAlbum } from "../_shared/albums.ts";
import { canUploadToAlbum } from "../_shared/permissions.ts";
import { isUuid, isValidFileSize } from "../_shared/validation.ts";

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
    return error("INVALID_REQUEST", "Please send valid completion details.", 400);
  }

  if (
    !isUuid(body.media_file_id) ||
    !isUuid(body.storage_object_id) ||
    !isProviderFileId(body.provider_file_id) ||
    !isValidFileSize(body.final_file_size_bytes)
  ) {
    return error("INVALID_REQUEST", "Please send valid completion details.", 400);
  }

  const checksum = cleanOptionalText(body.checksum, 255);
  if (body.checksum !== undefined && checksum === undefined) {
    return error("INVALID_REQUEST", "Checksum is invalid.", 400);
  }

  const mediaFileId = body.media_file_id;
  const storageObjectId = body.storage_object_id;
  const providerFileId = body.provider_file_id.trim();
  const finalFileSizeBytes = body.final_file_size_bytes;

  const { data: mediaFile, error: mediaError } = await supabaseAdmin
    .from("media_files")
    .select("id, album_id, uploader_id, storage_object_id, mime_type, file_size_bytes, upload_status")
    .eq("id", mediaFileId)
    .eq("storage_object_id", storageObjectId)
    .eq("is_deleted", false)
    .maybeSingle();

  if (mediaError) {
    console.error("complete-upload media lookup failed", mediaError.message);
    return error("SERVER_ERROR", "Could not load the upload. Please try again.", 500);
  }

  if (!mediaFile) {
    return error("FILE_NOT_FOUND", "This file is no longer available.", 404);
  }

  if (mediaFile.uploader_id !== user.id) {
    return error("FORBIDDEN", "You do not have permission to complete this upload.", 403);
  }

  const canUpload = await canUploadToAlbum(mediaFile.album_id, user.id);
  if (!canUpload) {
    await markUploadFailed(mediaFileId);
    return error("FORBIDDEN", "You do not have permission to upload to this album.", 403);
  }

  if (!["pending", "uploading"].includes(mediaFile.upload_status)) {
    return error("UPLOAD_FAILED", "This upload is no longer waiting for completion.", 400);
  }

  if (finalFileSizeBytes !== mediaFile.file_size_bytes) {
    await markUploadFailed(mediaFileId);
    return error("UPLOAD_FAILED", "Upload size did not match. Please try again.", 400);
  }

  let thumbnailUrl: string | null = null;

  try {
    const metadata = await getDriveFileMetadata(providerFileId);
    const googleSize = parseGoogleDriveSize(metadata.size);

    if (googleSize !== null && googleSize !== finalFileSizeBytes) {
      await markUploadFailed(mediaFileId);
      return error("UPLOAD_FAILED", "Upload size did not match. Please try again.", 400);
    }

    if (metadata.mimeType !== mediaFile.mime_type) {
      await markUploadFailed(mediaFileId);
      return error("UPLOAD_FAILED", "Uploaded file type did not match. Please try again.", 400);
    }

    thumbnailUrl = metadata.thumbnailLink ?? null;
  } catch (driveError) {
    console.error("complete-upload Google Drive confirmation failed", driveError);
    await markUploadFailed(mediaFileId);
    return error("STORAGE_ERROR", "Could not confirm the uploaded file. Please try again.", 500);
  }

  const { error: storageUpdateError } = await supabaseAdmin
    .from("storage_objects")
    .update({
      provider_file_id: providerFileId,
      file_size_bytes: finalFileSizeBytes,
      checksum: checksum ?? null,
    })
    .eq("id", storageObjectId);

  if (storageUpdateError) {
    console.error("complete-upload storage update failed", storageUpdateError.message);
    await markUploadFailed(mediaFileId);
    return error("SERVER_ERROR", "Could not save the upload. Please try again.", 500);
  }

  const uploadedAt = new Date().toISOString();
  const { data: completedFile, error: mediaUpdateError } = await supabaseAdmin
    .from("media_files")
    .update({
      file_size_bytes: finalFileSizeBytes,
      upload_status: "completed",
      uploaded_at: uploadedAt,
      ...(thumbnailUrl ? { thumbnail_url: thumbnailUrl } : {}),
    })
    .eq("id", mediaFileId)
    .select("id, upload_status, uploaded_at")
    .single();

  if (mediaUpdateError || !completedFile) {
    console.error("complete-upload media update failed", mediaUpdateError?.message);
    await markUploadFailed(mediaFileId);
    return error("SERVER_ERROR", "Could not finish the upload. Please try again.", 500);
  }

  // Update album cover thumbnail to the most recent file's thumbnail
  if (thumbnailUrl) {
    const { error: coverError } = await supabaseAdmin
      .from("albums")
      .update({ cover_thumbnail_url: thumbnailUrl })
      .eq("id", mediaFile.album_id);

    if (coverError) {
      console.warn("complete-upload cover thumbnail update failed", coverError.message);
      // Non-fatal — upload still succeeded
    }
  }

  await touchAlbum(mediaFile.album_id);

  return success({
    media_file_id: completedFile.id,
    upload_status: completedFile.upload_status,
    uploaded_at: completedFile.uploaded_at,
  });
});

async function markUploadFailed(mediaFileId: string) {
  const { error: updateError } = await supabaseAdmin
    .from("media_files")
    .update({ upload_status: "failed" })
    .eq("id", mediaFileId);

  if (updateError) {
    console.error("complete-upload failed status update failed", updateError.message);
  }
}

function isProviderFileId(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0 && value.trim().length <= 256;
}

function cleanOptionalText(value: unknown, maxLength: number) {
  if (value === null || value === undefined) return null;
  if (typeof value !== "string") return undefined;

  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > maxLength) return undefined;

  return trimmed;
}

function parseGoogleDriveSize(size: string | undefined) {
  if (!size) return null;

  const parsed = Number(size);
  if (!Number.isFinite(parsed)) return null;

  return parsed;
}
