/**
 * Pic Collector push notifications.
 *
 * Two Firestore triggers on the existing `friend_requests` collection:
 *  1. A request is created  -> notify the RECEIVER ("X sent you a request").
 *  2. A request flips to accepted -> notify the original SENDER ("Y accepted").
 *
 * Devices register their FCM token in `users/{uid}/fcmTokens/{token}`.
 * We read those tokens, send with a HIGH android priority so the OS draws the
 * banner on the lock screen / at the top of the screen, and prune dead tokens.
 */
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions/v2";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/** Must match kNotificationChannelId in lib/services/push_notification_service.dart */
const CHANNEL_ID = "friend_activity";

/** Error codes that mean the token should be deleted rather than retried. */
const INVALID_TOKEN_CODES = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

/**
 * Loads every registered token for `uid` and sends a high-priority push to
 * all of them at once, then removes any tokens FCM reports as dead.
 *
 * @param {string} uid        Recipient's uid.
 * @param {{title: string, body: string, data: Object<string,string>}} payload
 */
async function sendToUser(uid, { title, body, data }) {
  const tokensRef = db.collection("users").doc(uid).collection("fcmTokens");
  const snapshot = await tokensRef.get();

  const tokens = snapshot.docs
    .map((doc) => doc.data().token)
    .filter((token) => typeof token === "string" && token.length > 0);

  if (tokens.length === 0) {
    logger.log(`No push tokens registered for uid=${uid}`);
    return;
  }

  // Every value in `data` MUST be a string for FCM delivery.
  const dataPayload = { ...data, channelId: CHANNEL_ID };

  const message = {
    notification: { title, body },
    data: dataPayload,
    android: {
      priority: "high",
      notification: {
        channelId: CHANNEL_ID,
        icon: "mipmap/ic_launcher",
      },
    },
    apns: {
      payload: { aps: { sound: "default" } },
    },
    tokens,
  };

  try {
    const response = await messaging.sendEachForMulticast(message);
    logger.log(
      `Sent to uid=${uid}: ${response.successCount}/${tokens.length} succeeded`
    );

    // Prune tokens that FCM says are permanently invalid.
    const deadTokens = [];
    response.responses.forEach((result, index) => {
      if (result.success) return;
      const code = result.error?.code;
      if (INVALID_TOKEN_CODES.has(code)) {
        deadTokens.push(tokens[index]);
        logger.log(`Removing dead token ${tokens[index]} (${code})`);
      } else {
        logger.warn(`Send failed for token=${tokens[index]}: ${code}`);
      }
    });
    if (deadTokens.length > 0) {
      await Promise.all(deadTokens.map((token) => tokensRef.doc(token).delete()));
    }
  } catch (error) {
    logger.error(`sendToUser(uid=${uid}) failed`, error);
  }
}

/** "Firstname Surname" falling back to the username, then to "Someone". */
function displayNameOf(user) {
  const full = `${user?.firstName ?? ""} ${user?.surname ?? ""}`.trim();
  if (full) return full;
  if (user?.username) return `@${user.username}`;
  return "Someone";
}

/** Reads a `users/{uid}` profile (null when it does not exist). */
async function loadProfile(uid) {
  if (!uid) return null;
  const snap = await db.collection("users").doc(uid).get();
  return snap.exists ? snap.data() : null;
}

/**
 * (1) New friend request -> notify the receiver.
 */
export const onFriendRequestCreated = onDocumentCreated(
  "friend_requests/{requestId}",
  async (event) => {
    const request = event.data?.data();
    if (!request || request.status !== "pending") return;

    const receiverUid = request.toUid;
    const senderUid = request.fromUid;
    if (!receiverUid || !senderUid) return;
    if (receiverUid === senderUid) return;

    const sender = await loadProfile(senderUid);

    await sendToUser(receiverUid, {
      title: "New friend request",
      body: `${displayNameOf(sender)} sent you a friend request`,
      data: {
        type: "friend_request",
        fromUid: senderUid,
        requestId: event.params.requestId,
      },
    });
  }
);

/**
 * (2) Request accepted -> notify the ORIGINAL SENDER.
 *
 * The accept batch writes status: pending -> accepted, plus the friendship
 * mirrors. We only fire when that specific transition happens.
 */
export const onFriendRequestAccepted = onDocumentUpdated(
  "friend_requests/{requestId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const wasPending = before.status === "pending";
    const isAccepted = after.status === "accepted";
    if (!wasPending || !isAccepted) return;

    const senderUid = after.fromUid; // original sender (now friends)
    const accepterUid = after.toUid; // receiver who accepted
    if (!senderUid || !accepterUid) return;

    const accepter = await loadProfile(accepterUid);

    await sendToUser(senderUid, {
      title: "Friend request accepted",
      body: `${displayNameOf(accepter)} accepted your friend request`,
      data: {
        type: "friend_accepted",
        fromUid: accepterUid, // tapping opens this person's profile
        requestId: event.params.requestId,
      },
    });
  }
);
