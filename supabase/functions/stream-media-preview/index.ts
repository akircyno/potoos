import type { User } from "npm:@supabase/supabase-js@2";
import { corsHeaders, handleCors } from "../_shared/cors.ts";
import { fetchDriveFileContent } from "../_shared/googleDrive.ts";
import { isAlbumMember } from "../_shared/permissions.ts";
import { error } from "../_shared/response.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { isUuid } from "../_shared/validation.ts";

Deno.serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "GET") {
    return error("INVALID_REQUEST", "Please send a GET request.", 405);
  }

  const url = new URL(req.url);
  const mediaFileId = url.searchParams.get("media_file_id");
  if (!isUuid(mediaFileId)) {
    return error("INVALID_REQUEST", "Please send a valid file id.", 400);
  }

  const user = await getUserFromRequestOrQuery(req, url);
  if (!user) {
    return error("UNAUTHENTICATED", "Please log in to continue.", 401);
  }

  const { data: mediaFile, error: mediaError } = await supabaseAdmin
    .from("media_files")
    .select("id, album_id, storage_object_id, mime_type, upload_status, is_deleted, permanently_deleted_at")
    .eq("id", mediaFileId)
    .maybeSingle();

  if (mediaError) {
    console.error("stream-media-preview media lookup failed", mediaError.message);
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

  if (!mediaFile.mime_type?.toString().toLowerCase().startsWith("video/")) {
    return error("INVALID_REQUEST", "Video preview is only available for videos.", 400);
  }

  const member = await isAlbumMember(mediaFile.album_id, user.id);
  if (!member) {
    return error("FORBIDDEN", "You do not have permission to preview this file.", 403);
  }

  const { data: storageObject, error: storageError } = await supabaseAdmin
    .from("storage_objects")
    .select("provider_file_id, file_size_bytes, is_deleted")
    .eq("id", mediaFile.storage_object_id)
    .eq("is_deleted", false)
    .maybeSingle();

  if (storageError) {
    console.error("stream-media-preview storage lookup failed", storageError.message);
    return error("SERVER_ERROR", "Could not load the preview. Please try again.", 500);
  }

  if (!storageObject?.provider_file_id) {
    return error("FILE_NOT_FOUND", "Preview is not ready yet.", 404);
  }

  try {
    const range = req.headers.get("Range") ?? defaultPreviewRange(storageObject.file_size_bytes);
    const driveResponse = await fetchDriveFileContent(storageObject.provider_file_id, range);
    const headers = new Headers(corsHeaders);

    headers.set("Content-Type", mediaFile.mime_type);
    headers.set("Accept-Ranges", "bytes");
    headers.set("Cache-Control", "private, max-age=1800");
    copyHeader(driveResponse.headers, headers, "Content-Length");
    copyHeader(driveResponse.headers, headers, "Content-Range");

    return new Response(driveResponse.body, {
      status: driveResponse.status,
      headers,
    });
  } catch (previewError) {
    console.error("stream-media-preview Drive stream failed", previewError);
    return error("STORAGE_ERROR", "Could not load the video preview. Please try again.", 502);
  }
});

async function getUserFromRequestOrQuery(req: Request, url: URL): Promise<User | null> {
  const authHeader = req.headers.get("Authorization");
  const token = authHeader?.replace(/^Bearer\s+/i, "").trim() ||
    url.searchParams.get("access_token")?.trim();

  if (!token) return null;

  const { data, error: authError } = await supabaseAdmin.auth.getUser(token);
  if (authError || !data.user) return null;

  return data.user;
}

function defaultPreviewRange(size: number | null | undefined) {
  if (!size || size <= 0) return "bytes=0-1048575";
  const end = Math.min(size - 1, 1048575);
  return `bytes=0-${end}`;
}

function copyHeader(from: Headers, to: Headers, name: string) {
  const value = from.get(name);
  if (value) to.set(name, value);
}
