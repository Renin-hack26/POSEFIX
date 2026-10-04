// FixPose — OTP edge function (PLANNING §5.1, DEPLOYMENT.md).
//
// Sends 6-digit verification codes through the project's GMAIL SMTP App
// Password (GMAIL_ADDRESS/GMAIL_APP_PASSWORD secrets — never bundled in the
// app) and verifies them against the `otp_codes` table.
//
// Actions (POST JSON, requires the project anon/publishable key as Bearer):
//   send          { email, purpose: 'signup' | 'reset' }
//   verify        { email, code }
//   check-user    { email }                    forgot-password + sign-in
//                                              "User doesn't exist" gate.
//                                              Reads public.profiles first
//                                              (written by create-user,
//                                              self-healed on fallback
//                                              hits); falls back to the
//                                              GoTrue admin scan when the
//                                              table is missing or the
//                                              account predates it.
//   create-user   { email, password, metadata } after a verified signup OTP
//   reset-password{ email, password }          after a verified reset OTP

import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GMAIL_ADDRESS = Deno.env.get("GMAIL_ADDRESS")!;
const GMAIL_APP_PASSWORD = Deno.env.get("GMAIL_APP_PASSWORD")!;

/** Mirrors AppConstants.otpResendCooldown / the OTP screen copy. */
const RESEND_COOLDOWN_MS = 60_000;
const OTP_TTL_MS = 10 * 60_000;
const MAX_ATTEMPTS = 5;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Uniform 6-digit code (rejection sampling keeps each digit unbiased). */
function randomCode(): string {
  let out = "";
  while (out.length < 6) {
    const b = crypto.getRandomValues(new Uint8Array(1))[0];
    if (b < 250) out += String(b % 10);
  }
  return out;
}

type OtpRow = {
  email: string;
  code_hash: string;
  purpose: string;
  attempts: number;
  expires_at: string;
  verified_at: string | null;
  created_at: string;
};

async function getRow(email: string): Promise<OtpRow | null> {
  const { data, error } = await db
    .from("otp_codes")
    .select("*")
    .eq("email", email)
    .maybeSingle();
  if (error) throw error;
  return data as OtpRow | null;
}

type FoundUser = { id: string } | null;

/** GoTrue admin has no email filter — page through until found. */
async function findUser(email: string): Promise<FoundUser> {
  for (let page = 1; page <= 20; page++) {
    const { data, error } = await db.auth.admin.listUsers({ page, perPage: 100 });
    if (error) throw error;
    const hit = data.users.find(
      (u) => u.email?.toLowerCase() === email.toLowerCase(),
    );
    if (hit) return { id: hit.id };
    if (data.users.length < 100) return null;
  }
  return null;
}

function emailHtml(code: string, purpose: string): string {
  const headline =
    purpose === "reset" ? "Reset your password" : "Create your account";
  return `<!doctype html>
<html><body style="margin:0;background:#F4F5F0;font-family:Arial,Helvetica,sans-serif;">
  <div style="max-width:520px;margin:0 auto;padding:32px 20px;">
    <div style="background:#0F172A;border-radius:20px;padding:28px 24px;">
      <div style="display:inline-block;background:linear-gradient(160deg,#D9FF57,#7CC414);border-radius:12px;padding:8px 14px;font-weight:800;color:#1C2A06;font-size:15px;letter-spacing:0.5px;">FixPose</div>
      <p style="color:#EDF2E4;font-size:15px;margin:22px 0 6px;">${headline}</p>
      <p style="color:#A7B29D;font-size:13px;margin:0 0 20px;">Enter this 6-digit code to continue. It expires in 10 minutes.</p>
      <div style="background:#1B2118;border:1px dashed #7CC414;border-radius:14px;padding:18px;text-align:center;">
        <span style="color:#D9FF57;font-size:34px;font-weight:800;letter-spacing:10px;">${code}</span>
      </div>
      <p style="color:#77826E;font-size:12px;margin:20px 0 0;">If you didn't request this, you can safely ignore this email.</p>
    </div>
    <p style="color:#98A2B3;font-size:11px;text-align:center;margin-top:14px;">FixPose &middot; 100% on-device pose coaching</p>
  </div>
</body></html>`;
}

async function actionSend(email: string, purpose: string): Promise<Response> {
  const existing = await getRow(email);
  if (
    existing &&
    Date.now() - new Date(existing.created_at).getTime() < RESEND_COOLDOWN_MS
  ) {
    return json({ ok: false, error: "cooldown" }, 429);
  }

  const code = randomCode();
  const codeHash = await sha256Hex(`${email}:${code}`);
  const { error: upErr } = await db.from("otp_codes").upsert({
    email,
    code_hash: codeHash,
    purpose,
    attempts: 0,
    verified_at: null,
    expires_at: new Date(Date.now() + OTP_TTL_MS).toISOString(),
    created_at: new Date().toISOString(),
  });
  if (upErr) {
    console.error("otp upsert", upErr);
    return json({ ok: false, error: "db" }, 500);
  }

  try {
    const transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 465,
      secure: true,
      auth: { user: GMAIL_ADDRESS, pass: GMAIL_APP_PASSWORD },
    });
    await transporter.sendMail({
      from: `FixPose <${GMAIL_ADDRESS}>`,
      to: email,
      subject: `Your FixPose verification code — ${code}`,
      text: `Your verification code is ${code}. It expires in 10 minutes.`,
      html: emailHtml(code, purpose),
    });
  } catch (err) {
    console.error("smtp send failed", err);
    // Roll the row back so the user can resend immediately.
    await db.from("otp_codes").delete().eq("email", email);
    return json({ ok: false, error: "email_failed" }, 502);
  }
  return json({ ok: true });
}

async function requireVerified(
  email: string,
  purpose: string,
): Promise<Response | OtpRow> {
  const row = await getRow(email);
  if (!row || row.purpose !== purpose || !row.verified_at) {
    return json({ ok: false, error: "not_verified" }, 403);
  }
  if (Date.now() > new Date(row.expires_at).getTime()) {
    return json({ ok: false, error: "expired" }, 400);
  }
  return row;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }
  if (req.method !== "POST") {
    return json({ ok: false, error: "method" }, 405);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: "bad_json" }, 400);
  }

  const action = String(body.action ?? "");
  const email = String(body.email ?? "").trim().toLowerCase();
  if (!EMAIL_RE.test(email)) {
    return json({ ok: false, error: "bad_email" }, 400);
  }

  try {
    switch (action) {
      case "send": {
        const purpose = body.purpose === "reset" ? "reset" : "signup";
        return await actionSend(email, purpose);
      }

      case "verify": {
        const code = String(body.code ?? "");
        if (!/^\d{6}$/.test(code)) {
          return json({ ok: false, error: "bad_code" }, 400);
        }
        const row = await getRow(email);
        if (!row) return json({ ok: false, error: "expired" }, 400);
        if (Date.now() > new Date(row.expires_at).getTime()) {
          return json({ ok: false, error: "expired" }, 400);
        }
        if (row.attempts >= MAX_ATTEMPTS) {
          return json({ ok: false, error: "locked" }, 400);
        }
        const hash = await sha256Hex(`${email}:${code}`);
        if (hash !== row.code_hash) {
          await db
            .from("otp_codes")
            .update({ attempts: row.attempts + 1 })
            .eq("email", email);
          return json({ ok: false, error: "invalid" }, 400);
        }
        await db
          .from("otp_codes")
          .update({ verified_at: new Date().toISOString() })
          .eq("email", email);
        return json({ ok: true });
      }

      case "check-user": {
        // Canonical registry first: one indexed exact lookup (email is
        // already lowercased above, matching the stored form).
        try {
          const prof = await db
            .from("profiles")
            .select("user_id")
            .eq("email", email)
            .maybeSingle();
          if (!prof.error && prof.data) {
            return json({ ok: true, exists: true });
          }
        } catch {
          // profiles table missing (schema not applied yet) — fall through
          // to the GoTrue scan below (previous behavior preserved).
        }
        // Fallback: page GoTrue (covers accounts created before the
        // registry existed; a hit self-heals the registry row).
        const user = await findUser(email);
        if (!user) return json({ ok: true, exists: false });
        try {
          await db.from("profiles").upsert({ user_id: user.id, email });
        } catch {
          // Best effort — the answer is already known.
        }
        return json({ ok: true, exists: true });
      }

      case "create-user": {
        const check = await requireVerified(email, "signup");
        if (check instanceof Response) return check;
        const password = String(body.password ?? "");
        if (password.length < 8) {
          return json({ ok: false, error: "bad_password" }, 400);
        }
        const { data: created, error } = await db.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: body.metadata ?? {},
        });
        if (error) {
          console.error("create user", error);
          const exists = error.message.toLowerCase().includes("already");
          return json({ ok: false, error: exists ? "exists" : "create_failed" }, 400);
        }
        // Register the canonical email→user row (check-user reads this;
        // failure here must not fail the signup — the fallback scan covers it).
        try {
          const newId = (created as { user?: { id?: string } } | null)?.user?.id;
          if (newId) {
            await db.from("profiles").upsert({ user_id: newId, email });
          }
        } catch (err) {
          console.error("profiles upsert", err);
        }
        await db.from("otp_codes").delete().eq("email", email);
        return json({ ok: true });
      }

      case "reset-password": {
        const check = await requireVerified(email, "reset");
        if (check instanceof Response) return check;
        const password = String(body.password ?? "");
        if (password.length < 8) {
          return json({ ok: false, error: "bad_password" }, 400);
        }
        const user = await findUser(email);
        if (!user) return json({ ok: false, error: "no_user" }, 404);
        const { error } = await db.auth.admin.updateUserById(user.id, {
          password,
        });
        if (error) {
          console.error("reset password", error);
          return json({ ok: false, error: "reset_failed" }, 500);
        }
        await db.from("otp_codes").delete().eq("email", email);
        return json({ ok: true });
      }

      default:
        return json({ ok: false, error: "unknown_action" }, 400);
    }
  } catch (err) {
    console.error("unhandled", err);
    return json({ ok: false, error: "server" }, 500);
  }
});
