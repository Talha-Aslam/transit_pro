/**
 * AI first-line support for the "Live Chat" screen.
 *
 * Mirrors the Flutter side exactly: `chats/{chatId}` and
 * `chats/{chatId}/messages/{messageId}`, the same collections
 * `MessagingRepository` (transit_core) reads and writes. A support thread's
 * `participants` always contains the fixed sentinel `'support'`
 * (`kSupportParticipantId` in Dart) — there is no single real admin uid to
 * address, so that's how this function recognises "this is a support
 * thread" versus an ordinary driver<->parent chat it must never touch.
 *
 * State machine, kept on the thread document's `status` field:
 *   ai_active    -> every new user message gets a reply from this function
 *   admin_active -> this function goes silent; a human is expected to reply
 *
 * Escalation is a tool call, not text-parsing: the model is given a single
 * `escalate_to_admin` tool and decides on its own whether to use it, the
 * same way it would decide whether to answer in English or Urdu — no
 * "if the reply contains 'I don't know'" heuristics that a slightly
 * different phrasing could dodge.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const Anthropic = require("@anthropic-ai/sdk");

admin.initializeApp();
const db = admin.firestore();

// Set once with:
//   firebase functions:secrets:set ANTHROPIC_API_KEY
// Never hardcode the key here — `defineSecret` injects it at runtime from
// Secret Manager, and only into this function, not into the client bundle.
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

// Must match `kSupportParticipantId` / `kSupportAiSenderId` in
// `transit_core/lib/src/models/messaging.dart` exactly — these are the
// Dart and Node sides of the same constant, not independently chosen.
const SUPPORT_PARTICIPANT_ID = "support";
const SUPPORT_AI_SENDER_ID = "support_ai";

const MODEL = "claude-sonnet-4-5";
const HISTORY_LIMIT = 20;

// ─── System prompt ──────────────────────────────────────────────────────────
//
// Example only — this is the one part of this file you should actually
// rewrite for your own fare numbers, hours, and policies before relying on
// it. Keep it honest: telling the model about a feature that doesn't exist
// gets that lie repeated to a real user.
const SYSTEM_PROMPT = `You are the first-line support assistant for "Transit Pro", a school transport app connecting parents, students, and drivers. You are speaking directly to a signed-in user inside the app's Live Chat screen.

What you know about how the system works:
- Roles: a parent tracks their child's school bus and can manage several children; a student sees their own bus and schedule; a driver runs an assigned route and marks attendance.
- Missed Bus: if a student misses their scheduled bus, the parent or student can raise an ad-hoc pickup request pinned on a map. A nearby driver opens it, sends a fare offer, and the requester accepts or rejects that specific offer before any driver is dispatched — it is a negotiation, not an automatic assignment.
- Subscriptions: every account gets a 30-day free trial from sign-up. After the trial ends, the "Buy Subscription" screen is how they pay for continued access; there is a single paid plan, not several tiers.
- Emergency contacts: users can add/edit emergency contacts from their profile; a "Change Password" option is hidden for accounts that signed up with Google, since there is no password to change for them.
- Live tracking: once a driver starts their route, parents and students on that route see the bus's live location.
- Payments are handled outside the app between the family and the driver/school; the app itself never moves money.

Your job:
1. Answer clearly and briefly (2-3 sentences unless the question genuinely needs a list) using only what is written above, plus ordinary customer-support judgment for tone. Never invent a feature, price, or policy that is not listed here.
2. If you do not know the answer, the question needs access to the user's actual account/data, or the user explicitly asks for a human/admin/agent, call the "escalate_to_admin" tool instead of guessing or apologizing in a loop.
3. Never claim to be a human, and never claim an issue is fixed unless you are certain it is something explained above.`;

const ESCALATE_TOOL = {
  name: "escalate_to_admin",
  description:
    "Hand this conversation off to a human admin. Call this when the question can't be answered from what you were told, needs a look at the user's actual account, or the user explicitly asks for a human.",
  input_schema: {
    type: "object",
    properties: {
      reason: {
        type: "string",
        description: "One short sentence: why this needs a human, for the admin's notification.",
      },
    },
    required: ["reason"],
  },
};

// ─── Trigger ────────────────────────────────────────────────────────────────

exports.onSupportMessageCreated = onDocumentCreated(
  {
    document: "chats/{chatId}/messages/{messageId}",
    secrets: [ANTHROPIC_API_KEY],
  },
  async (event) => {
    const { chatId } = event.params;

    // Every support thread id contains the sentinel — see file doc comment.
    // This is the guard that keeps this function from ever touching an
    // ordinary driver<->parent chat, which has no AI/admin concept at all.
    if (!chatId.split("__").includes(SUPPORT_PARTICIPANT_ID)) return;

    const message = event.data?.data();
    if (!message) return;

    // Ignore the AI's own messages and an admin's replies — otherwise the
    // AI would reply to itself in a loop, or talk over an admin who has
    // already taken the conversation.
    if (message.senderRole && message.senderRole !== "user") return;

    const chatRef = db.collection("chats").doc(chatId);
    const chatSnap = await chatRef.get();
    const chat = chatSnap.data();

    // No thread doc, or an admin has already taken over: stay silent. This
    // is what "pause its own responses" means in practice — not a flag this
    // function checks and skips once, but a condition it re-checks on
    // every single incoming message for as long as the chat exists.
    if (!chat || chat.status !== "ai_active") return;

    const userUid = (chat.participants || []).find(
      (p) => p !== SUPPORT_PARTICIPANT_ID,
    );
    if (!userUid) {
      logger.error(`Support thread ${chatId} has no real participant`, { chatId });
      return;
    }

    const history = await loadHistory(chatRef);

    let response;
    try {
      const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
      response = await anthropic.messages.create({
        model: MODEL,
        max_tokens: 512,
        system: SYSTEM_PROMPT,
        tools: [ESCALATE_TOOL],
        messages: history,
      });
    } catch (err) {
      logger.error("Anthropic call failed", { chatId, error: String(err) });
      // Fail toward a human, not toward silence — a broken API key or an
      // outage should still get the user help, not leave them stuck with a
      // support screen that never answers.
      await escalate(chatRef, chatId, userUid, "The AI assistant failed to respond.");
      return;
    }

    const toolUse = response.content.find(
      (block) => block.type === "tool_use" && block.name === "escalate_to_admin",
    );

    if (toolUse) {
      const reason = toolUse.input?.reason || "Escalated by the AI assistant.";
      await escalate(chatRef, chatId, userUid, reason);
      return;
    }

    const textBlock = response.content.find((block) => block.type === "text");
    const reply = textBlock?.text?.trim();
    if (reply) await sendAiMessage(chatRef, userUid, reply);
  },
);

// ─── Helpers ────────────────────────────────────────────────────────────────

/** Oldest-first conversation history, shaped for the Anthropic Messages API. */
async function loadHistory(chatRef) {
  const snap = await chatRef
    .collection("messages")
    .orderBy("sentAt", "desc")
    .limit(HISTORY_LIMIT)
    .get();

  return snap.docs
    .reverse()
    .map((doc) => {
      const m = doc.data();
      const role = m.senderRole === "ai" ? "assistant" : "user";
      // A human admin's message is folded into the "user" side of the
      // model's turn history too — from the model's perspective once an
      // admin has spoken, it isn't going to be asked to reply again anyway
      // (status is `admin_active` by then), so this only matters for the
      // model's own trailing "assistant" turns being attributed correctly.
      return { role, content: String(m.text || "") };
    })
    .filter((turn) => turn.content.length > 0);
}

/** Writes one AI-authored message and updates the thread summary to match. */
async function sendAiMessage(chatRef, userUid, text) {
  const batch = db.batch();
  const msgRef = chatRef.collection("messages").doc();

  batch.set(msgRef, {
    senderId: SUPPORT_AI_SENDER_ID,
    senderRole: "ai",
    text,
    readBy: [SUPPORT_AI_SENDER_ID],
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  batch.set(
    chatRef,
    {
      lastMessage: text,
      lastSenderId: SUPPORT_AI_SENDER_ID,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      unreadCounts: { [userUid]: admin.firestore.FieldValue.increment(1) },
    },
    { merge: true },
  );

  await batch.commit();
}

/**
 * The handoff: sends the AI's final message, flips the thread to
 * `admin_active` (which is what makes this function go quiet on every
 * later message in this thread), and notifies every admin — an in-app
 * notification document each admin's own inbox already knows how to show,
 * plus a real push to any of their registered devices.
 */
async function escalate(chatRef, chatId, userUid, reason) {
  await sendAiMessage(
    chatRef,
    userUid,
    "Transferring you to an admin — someone will be with you shortly.",
  );
  await chatRef.set({ status: "admin_active" }, { merge: true });
  await notifyAdmins(chatId, userUid, reason);
}

/**
 * Fans an in-app notification out to every admin, and pushes to whichever
 * of their devices already hold an FCM token (`PushNotificationService` in
 * the Flutter app registers these under `users/{uid}.fcmTokens` today, but
 * nothing before this function ever actually sent a push through them).
 */
async function notifyAdmins(chatId, userUid, reason) {
  const adminsSnap = await db.collection("users").where("role", "==", "admin").get();
  if (adminsSnap.empty) {
    logger.warn("Chat escalated but no admin accounts exist", { chatId });
    return;
  }

  const notifBatch = db.batch();
  const tokens = [];
  for (const doc of adminsSnap.docs) {
    const itemRef = db
      .collection("notifications")
      .doc(doc.id)
      .collection("items")
      .doc();
    notifBatch.set(itemRef, {
      type: "chat",
      title: "Live Chat escalated",
      body: reason,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      data: { chatId, userUid },
    });
    for (const token of doc.data().fcmTokens || []) tokens.push(token);
  }
  await notifBatch.commit();

  if (tokens.length === 0) return;
  try {
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: "Live Chat escalated", body: reason },
      data: { chatId, type: "support_escalation" },
    });
  } catch (err) {
    // A failed push is not a failed escalation — the in-app notification
    // above already landed, and any invalid/expired tokens in the list
    // shouldn't fail the whole handoff.
    logger.error("Push to admins failed", { chatId, error: String(err) });
  }
}
