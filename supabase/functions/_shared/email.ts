export async function sendInviteEmail(params: {
  to: string;
  inviterName: string;
  albumName: string;
  role: string;
  inviteId?: string;
}): Promise<void> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) return;

  const appUrl = Deno.env.get("APP_URL") ?? "https://potoos.app";
  const deepLink = params.inviteId ? `${appUrl}/invites` : `${appUrl}/invites`;

  try {
    await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Potoos <onboarding@resend.dev>",
        to: params.to,
        subject: `${escape(params.inviterName)} invited you to ${escape(params.albumName)} on Potoos`,
        html: `
          <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;max-width:480px;margin:0 auto;padding:40px 24px;background:#FAF6F0">
            <p style="font-size:22px;font-weight:700;color:#4A1220;margin:0 0 16px">You've been invited.</p>
            <p style="font-size:15px;color:#24191B;line-height:1.65;margin:0 0 24px">
              <strong>${escape(params.inviterName)}</strong> invited you to join
              <strong>${escape(params.albumName)}</strong> on Potoos.
              Open the app to accept or decline.
            </p>
            <a href="${deepLink}"
               style="display:inline-block;background:#6B1C2E;color:#FAF6F0;text-decoration:none;font-size:14px;font-weight:600;padding:12px 28px;border-radius:8px;margin-bottom:32px">
              View invite
            </a>
            <hr style="border:none;border-top:1px solid #E9DED0;margin:0 0 20px" />
            <p style="font-size:12px;color:#B9A58A;margin:0">
              Potoos — original memories, safely shared.
            </p>
          </div>
        `,
      }),
    });
  } catch (err) {
    console.warn("sendInviteEmail failed", err);
  }
}

export async function sendDeclineNotificationEmail(params: {
  to: string;
  declinerName: string;
  albumName: string;
}): Promise<void> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) return;

  try {
    await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Potoos <onboarding@resend.dev>",
        to: params.to,
        subject: `${escape(params.declinerName)} declined your invite to ${escape(params.albumName)}`,
        html: `
          <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;max-width:480px;margin:0 auto;padding:40px 24px;background:#FAF6F0">
            <p style="font-size:16px;color:#24191B;line-height:1.65;margin:0 0 24px">
              <strong>${escape(params.declinerName)}</strong> declined your invite to
              <strong>${escape(params.albumName)}</strong>.
            </p>
            <hr style="border:none;border-top:1px solid #E9DED0;margin:0 0 20px" />
            <p style="font-size:12px;color:#B9A58A;margin:0">
              Potoos — original memories, safely shared.
            </p>
          </div>
        `,
      }),
    });
  } catch (err) {
    console.warn("sendDeclineNotificationEmail failed", err);
  }
}

function escape(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
