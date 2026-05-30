import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { uploadFileBytesToDrive } from "../_shared/googleDrive.ts";
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

  const mediaFileId = req.headers.get("x-media-file-id");
  const storageObjectId = req.headers.get("x-storage-object-id");

  if (!isUuid(mediaFileId) || !isUuid(storageObjectId)) {
    return error("INVALID_REQUEST", "Please send valid upload identifiers.", 400);
  }

  const { data: mediaFile, error: mediaError } = await supabaseAdmin
    .from("media_files")
    .select(`
      id,
      uploader_id,
      storage_object_id,
      original_filename,
      mime_type,
      file_size_bytes,
      upload_status,
      storage_objects (
        id,
        provider_folder_id,
        storage_path
      )
    `)
    .eq("id", mediaFileId)
    .eq("storage_object_id", storageObjectId)
    .eq("is_deleted", false)
    .maybeSingle();

  if (mediaError) {
    console.error("upload-original-file media lookup failed", mediaError.message);
    return error("SERVER_ERROR", "Could not load the upload. Please try again.", 500);
  }

  if (!mediaFile) {
    return error("FILE_NOT_FOUND", "This file is no longer available.", 404);
  }

  if (mediaFile.uploader_id !== user.id) {
    return error("FORBIDDEN", "You do not have permission to upload this file.", 403);
  }

  if (!["pending", "uploading", "failed"].includes(mediaFile.upload_status)) {
    return error("UPLOAD_FAILED", "This upload is no longer accepting file data.", 400);
  }

  const storageObject = Array.isArray(mediaFile.storage_objects)
    ? mediaFile.storage_objects[0]
    : mediaFile.storage_objects;

  if (!storageObject?.provider_folder_id || !storageObject?.storage_path) {
    return error("STORAGE_ERROR", "Storage is not ready for this upload.", 500);
  }

  const fileBytes = new Uint8Array(await req.arrayBuffer());

  if (fileBytes.byteLength !== mediaFile.file_size_bytes) {
    return error("UPLOAD_FAILED", "Upload size did not match. Please try again.", 400);
  }

  const filename = storageObject.storage_path.split("/").pop() ?? mediaFile.original_filename;

  const { error: uploadingError } = await supabaseAdmin
    .from("media_files")
    .update({ upload_status: "uploading" })
    .eq("id", mediaFileId);

  if (uploadingError) {
    console.error("upload-original-file status update failed", uploadingError.message);
    return error("SERVER_ERROR", "Could not start the upload. Please try again.", 500);
  }

  try {
    const driveFile = await uploadFileBytesToDrive({
      filename,
      mimeType: mediaFile.mime_type,
      parentFolderId: storageObject.provider_folder_id,
      fileSizeBytes: mediaFile.file_size_bytes,
      bytes: fileBytes,
    });

    const googleSize = parseGoogleDriveSize(driveFile.size);
    if (googleSize !== null && googleSize !== mediaFile.file_size_bytes) {
      return error("UPLOAD_FAILED", "Upload size did not match. Please try again.", 400);
    }

    const { error: storageUpdateError } = await supabaseAdmin
      .from("storage_objects")
      .update({
        provider_file_id: driveFile.id,
        file_size_bytes: mediaFile.file_size_bytes,
      })
      .eq("id", storageObjectId);

    if (storageUpdateError) {
      console.error("upload-original-file storage update failed", storageUpdateError.message);
      return error("SERVER_ERROR", "Could not save the uploaded file. Please try again.", 500);
    }

    const uploadedAt = new Date().toISOString();
    const { data: completedFile, error: mediaUpdateError } = await supabaseAdmin
      .from("media_files")
      .update({
        upload_status: "completed",
        uploaded_at: uploadedAt,
      })
      .eq("id", mediaFileId)
      .select("id, upload_status, uploaded_at")
      .single();

    if (mediaUpdateError || !completedFile) {
      console.error("upload-original-file media update failed", mediaUpdateError?.message);
      return error("SERVER_ERROR", "Could not finish the upload. Please try again.", 500);
    }

    return success({
      media_file_id: completedFile.id,
      upload_status: completedFile.upload_status,
      uploaded_at: completedFile.uploaded_at,
    });
  } catch (uploadError) {
    console.error("upload-original-file Google Drive upload failed", uploadError);
    await supabaseAdmin
      .from("media_files")
      .update({ upload_status: "failed" })
      .eq("id", mediaFileId);
    return error("STORAGE_ERROR", "Could not upload to Google Drive. Please try again.", 500);
  }
});

function parseGoogleDriveSize(size: string | undefined) {
  if (!size) return null;

  const parsed = Number(size);
  if (!Number.isFinite(parsed)) return null;

  return parsed;
}
