export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-media-file-id, x-storage-object-id",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Expose-Headers": "content-length, x-original-filename, x-file-size-bytes, x-mime-type",
};

export function handleCors(req: Request) {
  if (req.method !== "OPTIONS") return null;

  return new Response("ok", {
    headers: corsHeaders,
    status: 200,
  });
}
