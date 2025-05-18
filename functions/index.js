const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");
const sgMail = require("@sendgrid/mail");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

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

exports.notifyNewMessage = onDocumentCreated({
  document: "messages/{chatId}/chats/{messageId}",
  region: "us-central1"
}, async (event) => {
  const message = event.data.data();
  const chatId = event.params.chatId;
  const [userA, userB] = chatId.split("_");
  const recipientId = message.senderId === userA ? userB : userA;

  const senderDoc = await db.collection("users").doc(message.senderId).get();
  const recipientDoc = await db.collection("users").doc(recipientId).get();

  const sender = senderDoc.data();
  const recipient = recipientDoc.data();

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
    logger.info(`📨 Message notification sent to patient ${recipientId}`);
  }
});

exports.sendUnreadMessageDigest = onSchedule({
  schedule: "0 17 * * *",
  timeZone: "Asia/Amman",
  region: "us-central1"
}, async () => {
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

exports.notifyAppointmentChanged = onDocumentUpdated({
  document: "users/{userId}/appointments/{appointmentId}",
  region: "us-central1"
}, async (event) => {
  logger.info("✅ notifyAppointmentChanged triggered");

  const before = event.data.before.data();
  const after = event.data.after.data();
  const userId = event.params.userId;

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
