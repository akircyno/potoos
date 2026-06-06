import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { isValidAlbumName } from "../_shared/validation.ts";
import { logActivity } from "../_shared/activity.ts";

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
    return error("INVALID_REQUEST", "Please send valid album details.", 400);
  }

  if (!isValidAlbumName(body.name)) {
    return error("INVALID_REQUEST", "Album name cannot be empty.", 400);
  }

  const name = body.name.trim();
  const description = cleanOptionalText(body.description, 500);

  if (body.description !== undefined && description === undefined) {
    return error("INVALID_REQUEST", "Album description is too long.", 400);
  }

  const { data: profile, error: profileError } = await supabaseAdmin
    .from("user_profiles")
    .select("id, is_active, is_banned")
    .eq("id", user.id)
    .eq("is_active", true)
    .eq("is_banned", false)
    .maybeSingle();

  if (profileError) {
    console.error("create-album profile lookup failed", profileError.message);
    return error("SERVER_ERROR", "Could not load your profile. Please try again.", 500);
  }

  if (!profile) {
    return error("INVALID_REQUEST", "Please finish setting up your profile first.", 400);
  }

  const { data: storageProvider, error: providerError } = await supabaseAdmin
    .from("storage_providers")
    .select("id")
    .eq("name", "Google Drive Main")
    .eq("type", "google_drive")
    .eq("is_active", true)
    .maybeSingle();

  if (providerError) {
    console.error("create-album provider lookup failed", providerError.message);
    return error("SERVER_ERROR", "Could not prepare album storage. Please try again.", 500);
  }

  if (!storageProvider) {
    return error("SERVER_ERROR", "Album storage is not ready yet.", 500);
  }

  const { data: album, error: albumError } = await supabaseAdmin
    .from("albums")
    .insert({
      owner_id: user.id,
      name,
      description: description ?? null,
      storage_provider_id: storageProvider.id,
    })
    .select("id, name")
    .single();

  if (albumError || !album) {
    console.error("create-album album insert failed", albumError?.message);
    return error("SERVER_ERROR", "Could not create the album. Please try again.", 500);
  }

  const { error: memberError } = await supabaseAdmin
    .from("album_members")
    .insert({
      album_id: album.id,
      user_id: user.id,
      role: "admin",
      invited_by: user.id,
      is_active: true,
    });

  if (memberError) {
    console.error("create-album member insert failed", memberError.message);

    const { error: cleanupError } = await supabaseAdmin
      .from("albums")
      .delete()
      .eq("id", album.id);

    if (cleanupError) {
      console.error("create-album cleanup failed", cleanupError.message);
    }

    return error("SERVER_ERROR", "Could not finish creating the album. Please try again.", 500);
  }

  await logActivity(album.id, user.id, "album_created", { album_name: name });

  return success({
    album_id: album.id,
    name: album.name,
    role: "admin",
  }, 201);
});

function cleanOptionalText(value: unknown, maxLength: number) {
  if (value === null || value === undefined) return null;
  if (typeof value !== "string") return undefined;

  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > maxLength) return undefined;

  return trimmed;
}
