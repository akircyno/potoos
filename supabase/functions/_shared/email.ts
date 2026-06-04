export async function sendInviteEmail(params: {
  to: string;
  inviterName: string;
  albumName: string;
  role: string;
}): Promise<void> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) return; // no-op until RESEND_API_KEY secret is configured

  const roleLabel = params.role.charAt(0).toUpperCase() + params.role.slice(1);

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
        subject: `You've been invited to ${params.albumName} on Potoos`,
        html: `
          <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;max-width:480px;margin:0 auto;padding:40px 24px;background:#FAF6F0">
            <p style="font-size:22px;font-weight:700;color:#4A1220;margin:0 0 8px">You're invited.</p>
            <p style="font-size:15px;color:#24191B;line-height:1.65;margin:0 0 24px">
              <strong>${escape(params.inviterName)}</strong> invited you to join
              <strong>${escape(params.albumName)}</strong> on Potoos as a
              <strong style="color:#6B1C2E">${escape(roleLabel)}</strong>.
            </p>
            <p style="font-size:13px;color:#B9A58A;line-height:1.6;margin:0 0 32px">
              Open the Potoos app and sign in with your Google account to access this private space.
              Only the people who were actually there can see it.
            </p>
            <hr style="border:none;border-top:1px solid #E9DED0;margin:0 0 24px" />
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

function escape(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
