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

  const uploadBody = await readUploadBody(req);

  if (!uploadBody) {
    return error("INVALID_REQUEST", "Please send valid original file data.", 400);
  }

  const { mediaFileId, storageObjectId, fileBytes } = uploadBody;

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

  if (fileBytes.byteLength !== mediaFile.file_size_bytes) {
    await markUploadFailed(mediaFileId);
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
      await markUploadFailed(mediaFileId);
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
      await markUploadFailed(mediaFileId);
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
      await markUploadFailed(mediaFileId);
      return error("SERVER_ERROR", "Could not finish the upload. Please try again.", 500);
    }

    return success({
      media_file_id: completedFile.id,
      upload_status: completedFile.upload_status,
      uploaded_at: completedFile.uploaded_at,
    });
  } catch (uploadError) {
    console.error("upload-original-file Google Drive upload failed", uploadError);
    await markUploadFailed(mediaFileId);
    return error("STORAGE_ERROR", "Could not upload to Google Drive. Please try again.", 500);
  }
});

async function markUploadFailed(mediaFileId: string) {
  const { error: updateError } = await supabaseAdmin
    .from("media_files")
    .update({ upload_status: "failed" })
    .eq("id", mediaFileId);

  if (updateError) {
    console.error("upload-original-file failed status update failed", updateError.message);
  }
}

function parseGoogleDriveSize(size: string | undefined) {
  if (!size) return null;

  const parsed = Number(size);
  if (!Number.isFinite(parsed)) return null;

  return parsed;
}

async function readUploadBody(req: Request) {
  const contentType = req.headers.get("content-type")?.toLowerCase() ?? "";

  if (contentType.includes("application/json")) {
    try {
      const body = await req.json();
      const mediaFileId = typeof body.media_file_id === "string" ? body.media_file_id : null;
      const storageObjectId = typeof body.storage_object_id === "string"
        ? body.storage_object_id
        : null;
      const encodedFile = typeof body.file_data_base64 === "string"
        ? body.file_data_base64
        : null;

      if (!mediaFileId || !storageObjectId || !encodedFile) return null;

      return {
        mediaFileId,
        storageObjectId,
        fileBytes: decodeBase64Bytes(encodedFile),
      };
    } catch {
      return null;
    }
  }

  const mediaFileId = req.headers.get("x-media-file-id");
  const storageObjectId = req.headers.get("x-storage-object-id");
  if (!mediaFileId || !storageObjectId) return null;

  return {
    mediaFileId,
    storageObjectId,
    fileBytes: new Uint8Array(await req.arrayBuffer()),
  };
}

function decodeBase64Bytes(value: string) {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);

  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }

  return bytes;
}
