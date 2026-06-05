export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, content-range, x-media-file-id, x-storage-object-id, x-google-upload-url",
  "Access-Control-Allow-Methods": "POST, GET, PUT, OPTIONS",
  "Access-Control-Expose-Headers": "content-length, content-range, range, x-original-filename, x-file-size-bytes, x-mime-type",
};

export function handleCors(req: Request) {
  if (req.method !== "OPTIONS") return null;

  return new Response("ok", {
    headers: corsHeaders,
    status: 200,
  });
}
