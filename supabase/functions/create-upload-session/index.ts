import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import {
  createResumableUploadSession,
  getOrCreateDriveFolder,
} from "../_shared/googleDrive.ts";
import { canUploadToAlbum } from "../_shared/permissions.ts";
import { createSafeStorageFilename, getAlbumOriginalsPath } from "../_shared/storagePaths.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import {
  isUuid,
  isValidFilename,
  isValidFileSize,
  isValidFileType,
  isValidMimeType,
} from "../_shared/validation.ts";

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
    return error("INVALID_REQUEST", "Please send valid upload details.", 400);
  }

  if (
    !isUuid(body.album_id) ||
    !isValidFilename(body.original_filename) ||
    !isValidMimeType(body.mime_type) ||
    !isValidFileSize(body.file_size_bytes) ||
    !isValidFileType(body.file_type)
  ) {
    return error("INVALID_REQUEST", "Please send valid upload details.", 400);
  }

  if (!mimeMatchesFileType(body.mime_type, body.file_type)) {
    return error("INVALID_REQUEST", "File type does not match the MIME type.", 400);
  }

  const albumId = body.album_id;
  const originalFilename = body.original_filename.trim();
  const mimeType = body.mime_type.trim();
  const fileSizeBytes = body.file_size_bytes;
  const fileType = body.file_type;

  const { data: album, error: albumError } = await supabaseAdmin
    .from("albums")
    .select("id")
    .eq("id", albumId)
    .eq("is_deleted", false)
    .maybeSingle();

  if (albumError) {
    console.error("create-upload-session album lookup failed", albumError.message);
    return error("SERVER_ERROR", "Could not load the album. Please try again.", 500);
  }

  if (!album) {
    return error("ALBUM_NOT_FOUND", "This album is no longer available.", 404);
  }

  const canUpload = await canUploadToAlbum(albumId, user.id);

  if (!canUpload) {
    return error("FORBIDDEN", "You do not have permission to upload to this album.", 403);
  }

  const { data: storageProvider, error: providerError } = await supabaseAdmin
    .from("storage_providers")
    .select("id")
    .eq("name", "Google Drive Main")
    .eq("type", "google_drive")
    .eq("is_active", true)
    .maybeSingle();

  if (providerError) {
    console.error("create-upload-session provider lookup failed", providerError.message);
    return error("SERVER_ERROR", "Could not prepare storage. Please try again.", 500);
  }

  if (!storageProvider) {
    return error("STORAGE_ERROR", "Storage is not ready yet.", 500);
  }

  const { data: storageObject, error: storageObjectError } = await supabaseAdmin
    .from("storage_objects")
    .insert({
      provider_id: storageProvider.id,
      file_size_bytes: fileSizeBytes,
      mime_type: mimeType,
    })
    .select("id")
    .single();

  if (storageObjectError || !storageObject) {
    console.error("create-upload-session storage object insert failed", storageObjectError?.message);
    return error("SERVER_ERROR", "Could not prepare storage. Please try again.", 500);
  }

  const { data: mediaFile, error: mediaFileError } = await supabaseAdmin
    .from("media_files")
    .insert({
      album_id: albumId,
      uploader_id: user.id,
      storage_object_id: storageObject.id,
      original_filename: originalFilename,
      file_type: fileType,
      mime_type: mimeType,
      file_size_bytes: fileSizeBytes,
      upload_status: "pending",
    })
    .select("id")
    .single();

  if (mediaFileError || !mediaFile) {
    console.error("create-upload-session media file insert failed", mediaFileError?.message);
    await cleanupUploadRecords(null, storageObject.id);
    return error("SERVER_ERROR", "Could not prepare the upload. Please try again.", 500);
  }

  try {
    const rootFolderId = Deno.env.get("GOOGLE_DRIVE_ROOT_FOLDER_ID");
    if (!rootFolderId) {
      throw new Error("Missing Google Drive root folder.");
    }

    const albumFolder = await getOrCreateDriveFolder(`album_${albumId}`, rootFolderId);
    const originalsFolder = await getOrCreateDriveFolder("originals", albumFolder.id);
    const appEnv = Deno.env.get("APP_ENV") ?? "development";
    const storageDirectory = getAlbumOriginalsPath(appEnv, albumId);
    const storageFilename = createSafeStorageFilename(mediaFile.id, originalFilename);
    const storagePath = `${storageDirectory}/${storageFilename}`;

    const uploadUrl = await createResumableUploadSession({
      filename: storageFilename,
      mimeType,
      parentFolderId: originalsFolder.id,
      fileSizeBytes,
    });

    const { error: updateError } = await supabaseAdmin
      .from("storage_objects")
      .update({
        provider_folder_id: originalsFolder.id,
        storage_path: storagePath,
      })
      .eq("id", storageObject.id);

    if (updateError) {
      throw new Error("Failed to update storage object path.");
    }

    return success({
      media_file_id: mediaFile.id,
      storage_object_id: storageObject.id,
      upload_url: "upload-drive-chunk",
      upload_method: "PUT",
      upload_strategy: "edge_drive_resumable",
      chunk_size_bytes: 2 * 1024 * 1024,
      required_headers: {
        "Content-Type": mimeType,
        "X-Google-Upload-Url": uploadUrl,
      },
    }, 201);
  } catch (uploadError) {
    console.error("create-upload-session Google Drive setup failed", uploadError);
    await cleanupUploadRecords(mediaFile.id, storageObject.id);
    return error("STORAGE_ERROR", "Could not create the upload session. Please try again.", 500);
  }
});

function mimeMatchesFileType(mimeType: string, fileType: "photo" | "video") {
  if (fileType === "photo") return mimeType.toLowerCase().startsWith("image/");
  return mimeType.toLowerCase().startsWith("video/");
}

async function cleanupUploadRecords(mediaFileId: string | null, storageObjectId: string) {
  if (mediaFileId) {
    await supabaseAdmin.from("media_files").delete().eq("id", mediaFileId);
  }

  await supabaseAdmin.from("storage_objects").delete().eq("id", storageObjectId);
}
