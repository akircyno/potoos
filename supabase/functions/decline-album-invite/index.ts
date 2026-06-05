import { handleCors } from "../_shared/cors.ts";
import { error, success } from "../_shared/response.ts";
import { getUserFromRequest } from "../_shared/auth.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { isUuid } from "../_shared/validation.ts";
import { sendDeclineNotificationEmail } from "../_shared/email.ts";

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
    return error("INVALID_REQUEST", "Please send valid invite details.", 400);
  }

  if (!isUuid(body.invite_id)) {
    return error("INVALID_REQUEST", "Please send a valid invite id.", 400);
  }
  const inviteId = body.invite_id as string;

  const { data: invite, error: inviteError } = await supabaseAdmin
    .from("album_invites")
    .select("id, album_id, invited_user_id, invited_by_id, album_name, status")
    .eq("id", inviteId)
    .maybeSingle();

  if (inviteError) {
    console.error("decline-album-invite invite lookup failed", inviteError.message);
    return error("SERVER_ERROR", "Could not load the invite. Please try again.", 500);
  }
  if (!invite) {
    return error("NOT_FOUND", "Invite not found.", 404);
  }

  const inv = invite as Record<string, unknown>;

  if (inv.invited_user_id !== user.id) {
    return error("FORBIDDEN", "This invite is not for you.", 403);
  }
  if (inv.status !== "pending") {
    return error("INVALID_REQUEST", "This invite has already been responded to.", 409);
  }

  // Mark declined.
  const { error: updateError } = await supabaseAdmin
    .from("album_invites")
    .update({ status: "declined", responded_at: new Date().toISOString() })
    .eq("id", inviteId);

  if (updateError) {
    console.error("decline-album-invite update failed", updateError.message);
    return error("SERVER_ERROR", "Could not decline the invite. Please try again.", 500);
  }

  // Notify inviter — fetch their email and the decliner's name, then fire-and-forget.
  (async () => {
    try {
      const [{ data: declinerProfile }, { data: inviterProfile }] = await Promise.all([
        supabaseAdmin
          .from("user_profiles")
          .select("display_name")
          .eq("id", user.id)
          .maybeSingle(),
        supabaseAdmin
          .from("user_profiles")
          .select("email, display_name")
          .eq("id", inv.invited_by_id)
          .maybeSingle(),
      ]);

      if (inviterProfile?.email) {
        await sendDeclineNotificationEmail({
          to: inviterProfile.email as string,
          declinerName: declinerProfile?.display_name ?? "Someone",
          albumName: inv.album_name as string ?? "your album",
        });
      }
    } catch (e) {
      console.warn("decline-album-invite notification failed", e);
    }
  })();

  return success({ action: "declined" });
});
