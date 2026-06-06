import { supabaseAdmin } from "./supabaseAdmin.ts";

export type ActivityEventType =
  | "file_uploaded"
  | "member_joined"
  | "member_left"
  | "member_declined"
  | "album_created";

export async function logActivity(
  albumId: string,
  actorId: string,
  eventType: ActivityEventType,
  metadata: Record<string, unknown> = {},
): Promise<void> {
  const { error } = await supabaseAdmin
    .from("activity_events")
    .insert({ album_id: albumId, actor_id: actorId, event_type: eventType, metadata });

  if (error) {
    console.warn("logActivity failed", eventType, error.message);
  }
}
