import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { deleteDriveItem } from "../_shared/googleDrive.ts";

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

  const userId = user.id;
  const now = new Date().toISOString();

  // ── 1. Get all active memberships ──────────────────────────────────────────
  const { data: memberships, error: membershipsError } = await supabaseAdmin
    .from("album_members")
    .select("album_id, role")
    .eq("user_id", userId)
    .eq("is_active", true);

  if (membershipsError) {
    console.error("delete-account memberships lookup failed", membershipsError.message);
    return error("SERVER_ERROR", "Could not load your memberships. Please try again.", 500);
  }

  const adminAlbumIds = (memberships ?? [])
    .filter((m) => m.role === "admin")
    .map((m) => m.album_id as string);

  // ── 2. Delete each admin album (Drive folder + DB records) ─────────────────
  if (adminAlbumIds.length > 0) {
    const { data: albums } = await supabaseAdmin
      .from("albums")
      .select("id, storage_provider_id")
      .in("id", adminAlbumIds)
      .eq("is_deleted", false);

    for (const album of albums ?? []) {
      // Delete Drive folder (best-effort — non-fatal if it fails)
      if (album.storage_provider_id) {
        try {
          await deleteDriveItem(album.storage_provider_id);
        } catch (driveErr) {
          console.warn(`delete-account Drive folder ${album.storage_provider_id} failed:`, driveErr);
        }
      }

      // Mark all media_files permanently deleted
      await supabaseAdmin
        .from("media_files")
        .update({
          is_deleted: true,
          deleted_at: now,
          permanently_deleted_at: now,
          deleted_by: userId,
        })
        .eq("album_id", album.id)
        .isFilter("permanently_deleted_at", null);

      // Deactivate all album members
      await supabaseAdmin
        .from("album_members")
        .update({ is_active: false, removed_at: now })
        .eq("album_id", album.id)
        .eq("is_active", true);

      // Mark album as deleted
      await supabaseAdmin
        .from("albums")
        .update({ is_deleted: true, deleted_at: now, delete_expires_at: now })
        .eq("id", album.id);
    }
  }

  // ── 3. Remove user from all other albums ───────────────────────────────────
  await supabaseAdmin
    .from("album_members")
    .update({ is_active: false, removed_at: now })
    .eq("user_id", userId)
    .eq("is_active", true);

  // ── 4. Delete user profile ─────────────────────────────────────────────────
  const { error: profileError } = await supabaseAdmin
    .from("user_profiles")
    .delete()
    .eq("user_id", userId);

  if (profileError) {
    console.warn("delete-account profile delete failed", profileError.message);
    // Non-fatal — continue to auth deletion
  }

  // ── 5. Delete Supabase auth user (point of no return) ──────────────────────
  const { error: authDeleteError } =
    await supabaseAdmin.auth.admin.deleteUser(userId);

  if (authDeleteError) {
    console.error("delete-account auth delete failed", authDeleteError.message);
    return error(
      "SERVER_ERROR",
      "Could not fully delete your account. Please contact support.",
      500,
    );
  }

  return success({ deleted: true });
});
