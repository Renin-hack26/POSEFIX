// FixPose — website contact-form notifier (landing page "Get in touch").
//
// Receives submissions from the static site's contact form, archives the row
// in `contact_messages`, and emails the operator a designed briefing written
// as VEDA — the personal assistant — reporting to the boss.
//
// Secrets (never in site code): CONTACT_NOTIFY_EMAIL (recipient), plus the
// shared GMAIL_ADDRESS / GMAIL_APP_PASSWORD SMTP credentials used by send-otp.
//
// Request: POST JSON { name, email, topic, message, page?, website? }
//   - `website` is the honeypot field; filled bots get a fake success.
//   - Requires the project publishable key as Bearer (verify_jwt on).
//   - Per-IP throttle: >=30s between sends, max 10/hour (best effort).

import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GMAIL_ADDRESS = Deno.env.get("GMAIL_ADDRESS")!;
const GMAIL_APP_PASSWORD = Deno.env.get("GMAIL_APP_PASSWORD")!;
const CONTACT_NOTIFY_EMAIL = Deno.env.get("CONTACT_NOTIFY_EMAIL")!;

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const TOPICS = [
  "General enquiry",
  "Bug report",
  "Feature request",
  "Press & partnerships",
  "Other",
] as const;

const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function escapeHtml(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

/** Best-effort per-IP throttle (in-memory; resets with the isolate). */
const hits = new Map<string, number[]>();
function rateLimited(ip: string): boolean {
  const now = Date.now();
  const arr = (hits.get(ip) ?? []).filter((t) => now - t < 3_600_000);
  if (arr.length >= 10) return true;
  if (arr.length > 0 && now - arr[arr.length - 1] < 30_000) return true;
  arr.push(now);
  hits.set(ip, arr);
  return false;
}

type TopicMeta = { badge: string; flag: string };
const TOPIC_META: Record<string, TopicMeta> = {
  "General enquiry": {
    badge: "#059669",
    flag: "A standard enquiry — a quick reply keeps them happy.",
  },
  "Bug report": {
    badge: "#DC2626",
    flag: "Bugs go straight into the triage queue — flagging it for you.",
  },
  "Feature request": {
    badge: "#2563EB",
    flag: "Filed under product ideas for the next planning pass.",
  },
  "Press & partnerships": {
    badge: "#7C3AED",
    flag: "Marked for your personal attention.",
  },
  Other: { badge: "#475569", flag: "Uncategorised — worth a look." },
};

/** IST hour → assistant's time-of-day greeting. */
function greeting(d: Date): string {
  const hour = Number(
    d.toLocaleString("en-US", {
      timeZone: "Asia/Kolkata",
      hour: "numeric",
      hour12: false,
    }),
  );
  if (hour >= 5 && hour < 12) return "Good morning, boss.";
  if (hour >= 12 && hour < 17) return "Good afternoon, boss.";
  if (hour >= 17 && hour < 21) return "Good evening, boss.";
  return "Hello, boss.";
}

function istStamp(d: Date): string {
  return (
    d.toLocaleString("en-IN", {
      timeZone: "Asia/Kolkata",
      dateStyle: "medium",
      timeStyle: "short",
    }) + " IST"
  );
}

type Submission = {
  name: string;
  email: string;
  topic: string;
  message: string;
  page: string;
};

function vedaSubject(s: Submission): string {
  const who = s.name.length > 32 ? s.name.slice(0, 32) + "…" : s.name;
  const base = `Veda's briefing: ${s.topic} from ${who}`;
  return base.length > 120 ? base.slice(0, 117) + "…" : base;
}

function vedaHtml(s: Submission, sentAt: Date): string {
  const m = TOPIC_META[s.topic] ?? TOPIC_META.Other;
  const esc = escapeHtml;
  return `<!doctype html>
<html><body style="margin:0;padding:0;background:#F1F3EE;font-family:Georgia,'Times New Roman',serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F1F3EE;">
    <tr><td align="center" style="padding:28px 14px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#FFFFFF;border-radius:16px;overflow:hidden;border:1px solid #E3E7DB;">
        <tr>
          <td style="background:#0F172A;padding:18px 24px;">
            <span style="display:inline-block;background:linear-gradient(160deg,#D9FF57,#7CC414);border-radius:9px;padding:6px 12px;font-weight:800;color:#1C2A06;font-size:13px;letter-spacing:0.6px;font-family:Arial,Helvetica,sans-serif;">FixPose</span>
            <span style="float:right;color:#8F9B84;font-size:11px;letter-spacing:2.2px;font-family:Arial,Helvetica,sans-serif;line-height:30px;">VEDA &middot; ASSISTANT</span>
          </td>
        </tr>
        <tr><td style="padding:26px 26px 8px;">
          <p style="margin:0 0 10px;font-size:16px;color:#0F172A;font-weight:700;">${greeting(sentAt)}</p>
          <p style="margin:0;font-size:14px;line-height:1.6;color:#475569;">A visitor just wrote in through the FixPose website contact form. Full briefing below &mdash; I have filed a copy in the archive for you.</p>
        </td></tr>
        <tr><td style="padding:14px 26px 0;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F8F9F5;border:1px solid #E3E7DB;border-radius:12px;">
            <tr>
              <td style="padding:12px 16px;border-bottom:1px solid #E3E7DB;width:104px;color:#8A9182;font-size:10px;letter-spacing:1.6px;font-family:Arial,Helvetica,sans-serif;">FROM</td>
              <td style="padding:12px 16px;border-bottom:1px solid #E3E7DB;font-family:Arial,Helvetica,sans-serif;">
                <strong style="color:#0F172A;font-size:14px;">${esc(s.name)}</strong><br>
                <a href="mailto:${esc(s.email)}" style="color:#4B6512;font-size:13px;">${esc(s.email)}</a>
              </td>
            </tr>
            <tr>
              <td style="padding:12px 16px;border-bottom:1px solid #E3E7DB;color:#8A9182;font-size:10px;letter-spacing:1.6px;font-family:Arial,Helvetica,sans-serif;">TOPIC</td>
              <td style="padding:12px 16px;border-bottom:1px solid #E3E7DB;">
                <span style="display:inline-block;background:${m.badge};color:#FFFFFF;border-radius:999px;padding:4px 12px;font-size:12px;font-weight:700;font-family:Arial,Helvetica,sans-serif;">${esc(s.topic)}</span>
              </td>
            </tr>
            <tr>
              <td style="padding:12px 16px;border-bottom:1px solid #E3E7DB;color:#8A9182;font-size:10px;letter-spacing:1.6px;font-family:Arial,Helvetica,sans-serif;">RECEIVED</td>
              <td style="padding:12px 16px;border-bottom:1px solid #E3E7DB;color:#0F172A;font-size:13px;font-family:Arial,Helvetica,sans-serif;">${istStamp(sentAt)}</td>
            </tr>
            <tr>
              <td style="padding:12px 16px;color:#8A9182;font-size:10px;letter-spacing:1.6px;font-family:Arial,Helvetica,sans-serif;">PAGE</td>
              <td style="padding:12px 16px;color:#0F172A;font-size:13px;font-family:Arial,Helvetica,sans-serif;">${esc(s.page || "/")}</td>
            </tr>
          </table>
        </td></tr>
        <tr><td style="padding:20px 26px 0;">
          <p style="margin:0 0 8px;font-size:11px;letter-spacing:1.8px;color:#8A9182;font-family:Arial,Helvetica,sans-serif;">WHAT THEY SAID</p>
          <div style="background:#FBFCF8;border-left:4px solid #7CC414;border-radius:0 10px 10px 0;padding:14px 16px;font-size:14px;line-height:1.65;color:#1F2A3A;white-space:pre-wrap;font-family:Arial,Helvetica,sans-serif;">${esc(s.message)}</div>
        </td></tr>
        <tr><td style="padding:16px 26px 0;">
          <p style="margin:0;font-size:13px;line-height:1.6;color:#4B6512;font-style:italic;font-family:Arial,Helvetica,sans-serif;">&#9998; Veda&rsquo;s note: ${esc(m.flag)}</p>
        </td></tr>
        <tr><td style="padding:16px 26px 0;">
          <p style="margin:0;font-size:13px;line-height:1.65;color:#475569;font-family:Arial,Helvetica,sans-serif;">&#8594; Hit <strong>Reply</strong> and your words go straight to ${esc(s.name)} &mdash; no need to copy the address.</p>
        </td></tr>
        <tr><td style="padding:20px 26px 6px;">
          <p style="margin:0;font-size:15px;color:#0F172A;font-weight:700;font-style:italic;">&mdash; Veda</p>
          <p style="margin:2px 0 0;font-size:12px;color:#8A9182;font-family:Arial,Helvetica,sans-serif;">Personal assistant to the FixPose team</p>
        </td></tr>
        <tr><td style="padding:14px 26px 22px;">
          <p style="margin:0;padding-top:12px;border-top:1px solid #E3E7DB;font-size:11px;line-height:1.6;color:#98A2B3;font-family:Arial,Helvetica,sans-serif;">Delivered automatically by Veda from the website contact form &middot; archived in <code style="color:#6B7A5E;">contact_messages</code> &middot; ${istStamp(sentAt)}</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;
}

function vedaText(s: Submission, sentAt: Date): string {
  const m = TOPIC_META[s.topic] ?? TOPIC_META.Other;
  return [
    greeting(sentAt),
    "",
    "A visitor just wrote in through the FixPose website contact form. Full briefing below.",
    "",
    "  FROM      " + s.name + " <" + s.email + ">",
    "  TOPIC     " + s.topic,
    "  RECEIVED  " + istStamp(sentAt),
    "  PAGE      " + (s.page || "/"),
    "",
    "WHAT THEY SAID",
    "----------------------------------------",
    s.message,
    "----------------------------------------",
    "",
    "Veda's note: " + m.flag,
    "",
    "Reply to this email to reach " + s.name + " directly.",
    "",
    "-- Veda",
    "Personal assistant to the FixPose team",
    "",
    "Delivered automatically from the website contact form; archived in contact_messages.",
  ].join("\n");
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

  // Honeypot: bots fill every field. Fake success, store nothing.
  if (String(body.website ?? "").trim() !== "") {
    return json({ ok: true });
  }

  const name = String(body.name ?? "").trim();
  const email = String(body.email ?? "").trim().toLowerCase();
  const rawTopic = String(body.topic ?? "").trim();
  const message = String(body.message ?? "").trim();
  const page = String(body.page ?? "").trim().slice(0, 200);

  if (name.length < 1 || name.length > 120) {
    return json({ ok: false, error: "bad_name" }, 400);
  }
  if (!EMAIL_RE.test(email) || email.length > 254) {
    return json({ ok: false, error: "bad_email" }, 400);
  }
  if (message.length < 10 || message.length > 5000) {
    return json({ ok: false, error: "bad_message" }, 400);
  }
  const topic: string = (TOPICS as readonly string[]).includes(rawTopic)
    ? rawTopic
    : "Other";

  const ip =
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  if (rateLimited(ip)) {
    return json({ ok: false, error: "slow_down" }, 429);
  }

  if (!CONTACT_NOTIFY_EMAIL) {
    console.error("CONTACT_NOTIFY_EMAIL secret missing");
    return json({ ok: false, error: "config" }, 500);
  }

  const submission: Submission = { name, email, topic, message, page };
  const sentAt = new Date();

  // 1) Archive first (service role; table is insert-only for the public).
  const { error: insErr } = await db.from("contact_messages").insert({
    name,
    email,
    topic,
    message,
    page: page || null,
  });
  if (insErr) {
    console.error("contact insert", insErr);
    return json({ ok: false, error: "db" }, 500);
  }

  // 2) Brief the boss as Veda — roll the row back on SMTP failure so the
  //    visitor's retry doesn't double-file.
  try {
    const transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 465,
      secure: true,
      auth: { user: GMAIL_ADDRESS, pass: GMAIL_APP_PASSWORD },
    });
    await transporter.sendMail({
      from: `FixPose · Veda <${GMAIL_ADDRESS}>`,
      to: CONTACT_NOTIFY_EMAIL,
      replyTo: `"${name.replace(/["\\\r\n]/g, "")}" <${email}>`,
      subject: vedaSubject(submission),
      text: vedaText(submission, sentAt),
      html: vedaHtml(submission, sentAt),
    });
  } catch (err) {
    console.error("smtp send failed", err);
    await db
      .from("contact_messages")
      .delete()
      .eq("email", email)
      .eq("message", message);
    return json({ ok: false, error: "email_failed" }, 502);
  }

  return json({ ok: true });
});
