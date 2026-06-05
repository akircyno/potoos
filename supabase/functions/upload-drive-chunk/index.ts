import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { isUuid, isValidFileSize, isValidMimeType } from "../_shared/validation.ts";

const MAX_CHUNK_BYTES = 2 * 1024 * 1024;
const resumableUploadPrefix = "https://www.googleapis.com/upload/drive/";

Deno.serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "PUT") {
    return error("INVALID_REQUEST", "Please send a PUT request.", 405);
  }

  const { user, error: authError } = await getUserFromRequest(req);
  if (authError || !user) {
    return error("UNAUTHENTICATED", "Please log in to continue.", 401);
  }

  const mediaFileId = req.headers.get("x-media-file-id")?.trim();
  const storageObjectId = req.headers.get("x-storage-object-id")?.trim();
  const uploadUrl = req.headers.get("x-google-upload-url")?.trim();
  const contentRange = req.headers.get("content-range")?.trim();
  const requestMimeType = normalizeMimeType(req.headers.get("content-type"));

  if (
    !isUuid(mediaFileId) ||
    !isUuid(storageObjectId) ||
    !isSafeDriveUploadUrl(uploadUrl) ||
    !contentRange
  ) {
    return error("INVALID_REQUEST", "Please send valid upload chunk details.", 400);
  }

  const range = parseContentRange(contentRange);
  if (!range || !isValidFileSize(range.totalBytes)) {
    return error("INVALID_REQUEST", "Please send a valid upload byte range.", 400);
  }

  const { data: mediaFile, error: mediaError } = await supabaseAdmin
    .from("media_files")
    .select("id,uploader_id,storage_object_id,mime_type,file_size_bytes,upload_status")
    .eq("id", mediaFileId)
    .maybeSingle();

  if (mediaError) {
    console.error("upload-drive-chunk media lookup failed", mediaError.message);
    return error("SERVER_ERROR", "Could not load the upload. Please try again.", 500);
  }

  if (!mediaFile || mediaFile.storage_object_id !== storageObjectId) {
    return error("NOT_FOUND", "This upload is no longer available.", 404);
  }

  if (mediaFile.uploader_id !== user.id) {
    return error("FORBIDDEN", "You do not have permission to continue this upload.", 403);
  }

  if (!["pending", "uploading", "failed"].includes(mediaFile.upload_status)) {
    return error("UPLOAD_FAILED", "This upload cannot be continued.", 409);
  }

  if (Number(mediaFile.file_size_bytes) !== range.totalBytes) {
    return error("INVALID_REQUEST", "Upload size does not match the original file.", 400);
  }

  if (!isValidMimeType(mediaFile.mime_type)) {
    return error("SERVER_ERROR", "Upload metadata is incomplete. Please try again.", 500);
  }

  let chunk = new Uint8Array(0);

  if (!range.isProbe) {
    if (requestMimeType !== normalizeMimeType(mediaFile.mime_type)) {
      return error("INVALID_REQUEST", "Upload type does not match the original file.", 400);
    }

    chunk = new Uint8Array(await req.arrayBuffer());

    if (
      range.startByte == null ||
      range.endByte == null ||
      chunk.byteLength === 0 ||
      chunk.byteLength > MAX_CHUNK_BYTES ||
      chunk.byteLength !== range.endByte - range.startByte + 1 ||
      range.endByte >= range.totalBytes
    ) {
      return error("INVALID_REQUEST", "Upload chunk size does not match its byte range.", 400);
    }

    await supabaseAdmin
      .from("media_files")
      .update({ upload_status: "uploading" })
      .eq("id", mediaFileId)
      .in("upload_status", ["pending", "failed"]);
  }

  const driveHeaders = new Headers({
    "Content-Range": contentRange,
  });

  if (!range.isProbe) {
    driveHeaders.set("Content-Type", mediaFile.mime_type);
  }

  let driveResponse: Response;
  try {
    driveResponse = await fetch(uploadUrl, {
      method: "PUT",
      headers: driveHeaders,
      body: range.isProbe ? undefined : chunk,
    });
  } catch (fetchError) {
    console.error("upload-drive-chunk Drive fetch failed", fetchError);
    return error("STORAGE_ERROR", "Upload could not reach storage. Check your connection and try again.", 502);
  }

  const drivePayload = await parseDrivePayload(driveResponse);
  const driveStatus = driveResponse.status;
  const driveRange = driveResponse.headers.get("range");

  if (driveStatus === 308 || driveStatus === 200 || driveStatus === 201 || driveStatus === 404) {
    return success({
      status_code: driveStatus,
      range: driveRange,
      data: drivePayload,
    });
  }

  console.error("upload-drive-chunk Drive rejected chunk", {
    status: driveStatus,
    payload: drivePayload,
  });

  if (driveStatus === 408 || driveStatus === 429 || driveStatus >= 500) {
    return success({
      status_code: driveStatus,
      range: driveRange,
      data: drivePayload,
    });
  }

  return error("STORAGE_ERROR", "Upload was rejected by storage. Please try again.", 502);
});

type ParsedRange = {
  isProbe: boolean;
  startByte: number | null;
  endByte: number | null;
  totalBytes: number;
};

function parseContentRange(value: string): ParsedRange | null {
  const probeMatch = /^bytes \*\/(\d+)$/.exec(value);
  if (probeMatch) {
    return {
      isProbe: true,
      startByte: null,
      endByte: null,
      totalBytes: Number(probeMatch[1]),
    };
  }

  const chunkMatch = /^bytes (\d+)-(\d+)\/(\d+)$/.exec(value);
  if (!chunkMatch) return null;

  const startByte = Number(chunkMatch[1]);
  const endByte = Number(chunkMatch[2]);
  const totalBytes = Number(chunkMatch[3]);

  if (
    !Number.isSafeInteger(startByte) ||
    !Number.isSafeInteger(endByte) ||
    !Number.isSafeInteger(totalBytes) ||
    startByte < 0 ||
    endByte < startByte ||
    totalBytes <= 0
  ) {
    return null;
  }

  return {
    isProbe: false,
    startByte,
    endByte,
    totalBytes,
  };
}

function normalizeMimeType(value: string | null) {
  return (value ?? "").split(";")[0].trim().toLowerCase();
}

function isSafeDriveUploadUrl(value: string | undefined) {
  if (!value) return false;

  try {
    const url = new URL(value);
    return url.protocol === "https:" &&
      url.href.startsWith(resumableUploadPrefix) &&
      url.searchParams.get("uploadType") === "resumable";
  } catch {
    return false;
  }
}

async function parseDrivePayload(response: Response) {
  const text = await response.text();
  if (!text.trim()) return null;

  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}
