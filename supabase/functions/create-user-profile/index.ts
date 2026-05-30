import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";

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

  if (!user.email) {
    return error("INVALID_REQUEST", "Your account is missing an email address.", 400);
  }

  const email = user.email.trim().toLowerCase();

  let body: Record<string, unknown> = {};

  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const displayName = cleanOptionalText(
    body.display_name ?? user.user_metadata?.full_name ?? user.user_metadata?.name,
    100,
  );
  const avatarUrl = cleanOptionalText(body.avatar_url ?? user.user_metadata?.avatar_url, 2048);

  if (body.display_name !== undefined && displayName === undefined) {
    return error("INVALID_REQUEST", "Display name is invalid.", 400);
  }

  if (body.avatar_url !== undefined && avatarUrl === undefined) {
    return error("INVALID_REQUEST", "Avatar URL is invalid.", 400);
  }

  const { data: existingProfile, error: lookupError } = await supabaseAdmin
    .from("user_profiles")
    .select("id, email, display_name, avatar_url")
    .eq("id", user.id)
    .maybeSingle();

  if (lookupError) {
    console.error("create-user-profile lookup failed", lookupError.message);
    return error("SERVER_ERROR", "Could not load your profile. Please try again.", 500);
  }

  if (existingProfile) {
    const nextProfile = {
      email,
      display_name: displayName ?? existingProfile.display_name,
      avatar_url: avatarUrl ?? existingProfile.avatar_url,
      last_active_at: new Date().toISOString(),
      is_active: true,
    };

    const { data: updatedProfile, error: updateError } = await supabaseAdmin
      .from("user_profiles")
      .update(nextProfile)
      .eq("id", user.id)
      .select("id, email, display_name, avatar_url")
      .single();

    if (updateError || !updatedProfile) {
      console.error("create-user-profile update failed", updateError?.message);
      return error("SERVER_ERROR", "Could not update your profile. Please try again.", 500);
    }

    return success(toProfileResponse(updatedProfile));
  }

  const { data: profile, error: insertError } = await supabaseAdmin
    .from("user_profiles")
    .insert({
      id: user.id,
      email,
      display_name: displayName ?? null,
      avatar_url: avatarUrl ?? null,
      last_active_at: new Date().toISOString(),
    })
    .select("id, email, display_name, avatar_url")
    .single();

  if (insertError || !profile) {
    console.error("create-user-profile insert failed", insertError?.message);
    return error("SERVER_ERROR", "Could not create your profile. Please try again.", 500);
  }

  return success(toProfileResponse(profile), 201);
});

function cleanOptionalText(value: unknown, maxLength: number) {
  if (value === null || value === undefined) return null;
  if (typeof value !== "string") return undefined;

  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > maxLength) return undefined;

  return trimmed;
}

function toProfileResponse(profile: {
  id: string;
  email: string;
  display_name: string | null;
  avatar_url: string | null;
}) {
  return {
    user_id: profile.id,
    email: profile.email,
    display_name: profile.display_name,
    avatar_url: profile.avatar_url,
  };
}
