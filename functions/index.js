const functions = require("firebase-functions"); // ✅ Gen 1 compatible
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// ✅ Test Function
exports.helloWorld = functions
  .region("us-central1")
  .https
  .onRequest((req, res) => {
    res.send("✅ Hello from Safe Space!");
  });

// 🔔 Create Firestore Notification
async function createNotification(userId, title, body) {
  const notifRef = db.collection("users").doc(userId).collection("notifications").doc();
  await notifRef.set({
    title,
    body,
    timestamp: Timestamp.now(),
    read: false,
    digestSent: false,
  });
  logger.info(`🔔 Notification created for user: ${userId}`);
}

// ✅ Notify on New Message (deduplicated)
exports.notifyNewMessage = functions
  .region("us-central1")
  .firestore
  .document("messages/{chatId}/chats/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const chatId = context.params.chatId;
    const [userA, userB] = chatId.split("_");
    const recipientId = message.senderId === userA ? userB : userA;

    const senderDoc = await db.collection("users").doc(message.senderId).get();
    const recipientDoc = await db.collection("users").doc(recipientId).get();

    const sender = senderDoc.data();
    const recipient = recipientDoc.data();

    // ✅ Doctor → Patient
    if (
      recipient.role === "patient" &&
      recipient.doctorId === message.senderId &&
      recipient.fcmToken
    ) {
      const title = "New Message from Your Doctor";
      const body = `${sender.name || "Doctor"}: ${message.text || "Sent a message"}`;

      await messaging.send({
        token: recipient.fcmToken,
        notification: { title, body },
      });

      await createNotification(recipientId, title, body);
      logger.info(`📨 Message notification sent to patient ${recipientId}`);
      return;
    }

    // ✅ Patient → Doctor with deduplication
    if (
      sender.role === "patient" &&
      sender.doctorId === recipientId &&
      recipient.fcmToken
    ) {
      const lastNotifRef = db.collection("users").doc(recipientId)
        .collection("notifications")
        .where("title", "==", "New Message from Your Patient")
        .where("read", "==", false)
        .orderBy("timestamp", "desc")
        .limit(1);

      const existingNotif = await lastNotifRef.get();
      const recentAlreadyExists = !existingNotif.empty;

      if (!recentAlreadyExists) {
        const title = "New Message from Your Patient";
        const body = `${sender.name || "Patient"}: ${message.text || "Sent a message"}`;

        await messaging.send({
          token: recipient.fcmToken,
          notification: { title, body },
        });

        await createNotification(recipientId, title, body);
        logger.info(`📨 Message notification sent to doctor ${recipientId}`);
      } else {
        logger.info(`🔁 Skipped duplicate message notification to doctor ${recipientId}`);
      }
    }
  });

// ✅ Notify on Appointment Change
exports.notifyAppointmentChanged = functions
  .region("us-central1")
  .firestore
  .document("users/{userId}/appointments/{appointmentId}")
  .onUpdate(async (change, context) => {
    logger.info("✅ notifyAppointmentChanged triggered");

    const before = change.before.data();
    const after = change.after.data();
    const userId = context.params.userId;

    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.exists && userDoc.data().fcmToken;

    const formattedDate = after.dateTime.toDate().toLocaleString("en-US", {
      timeZone: "Asia/Amman",
      weekday: "long", year: "numeric", month: "long", day: "numeric",
      hour: "2-digit", minute: "2-digit"
    });

    let title = "", body = "";

    if (before.status !== after.status) {
      if (after.status.toLowerCase() === "cancelled") {
        title = "Appointment Canceled";
        body = "Your appointment has been cancelled.";
      } else {
        title = "Appointment Status Updated";
        body = `Your appointment status changed to \"${after.status}\".`;
      }
    } else if (
      before.note !== after.note ||
      before.dateTime.toMillis() !== after.dateTime.toMillis()
    ) {
      title = "Appointment Updated";
      body = `Your appointment has been updated to ${formattedDate}.`;
    }

    if (title && body) {
      await createNotification(userId, title, body);
      if (fcmToken) {
        try {
          await messaging.send({ token: fcmToken, notification: { title, body } });
        } catch (error) {
          logger.error("❌ FCM send error", error);
        }
      }
    }
  });

// ✅ Daily Digest for Unread Messages
exports.sendUnreadMessageDigest = functions
  .region("us-central1")
  .pubsub
  .schedule("0 17 * * *")
  .timeZone("Asia/Amman")
  .onRun(async () => {
    const patients = await db.collection("users").where("role", "==", "patient").get();

    for (const patientDoc of patients.docs) {
      const patient = patientDoc.data();
      const patientId = patientDoc.id;

      if (!patient.fcmToken || !patient.doctorId) continue;

      const chatsSnapshot = await db
        .collection(`messages/${patientId}/chats`)
        .where("isRead", "==", false)
        .get();

      let countFromDoctor = 0;
      for (const chat of chatsSnapshot.docs) {
        const data = chat.data();
        if (data.senderId === patient.doctorId) {
          countFromDoctor++;
        }
      }

      if (countFromDoctor > 0) {
        const title = "Unread Messages from Your Doctor";
        const body = `You have ${countFromDoctor} unread message(s) from your doctor. Open Safe Space to read them.`;

        await messaging.send({
          token: patient.fcmToken,
          notification: { title, body },
        });

        logger.info(`📬 Unread message digest sent to ${patientId}`);
      }
    }
  });
