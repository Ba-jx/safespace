const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

// 🔧 Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// ✅ Test HTTP function (optional)
exports.helloWorld = onRequest((req, res) => {
  logger.info("Hello logs!", { structuredData: true });
  res.send("Hello from Firebase!");
});

// 🔔 Cloud Function: Notify patient when appointment is updated
exports.notifyAppointmentChanged = onDocumentUpdated(
  "users/{userId}/appointments/{appointmentId}",
  async (event) => {
    logger.info("✅ notifyAppointmentChanged function triggered");

    const before = event.data.before.data();
    const after = event.data.after.data();

    const userId = event.params.userId;
    logger.info(`📍 Processing changes for user: ${userId}`);

    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.exists && userDoc.data().fcmToken;

    if (!fcmToken) {
      logger.warn("❌ No FCM token found for user. Notification skipped.");
      return;
    }

    let title = "";
    let body = "";

    // 🟡 Appointment status changed
    if (before.status !== after.status) {
      title = "Appointment Status Updated";
      body = `Your appointment status changed to "${after.status}".`;
      logger.info(`🔄 Status changed to: ${after.status}`);
    } else if (
      before.note !== after.note ||
      before.dateTime.toMillis() !== after.dateTime.toMillis()
    ) {
      // 🟡 Note or DateTime changed
      const newTime = after.dateTime.toDate().toLocaleString();
      title = "Appointment Updated";
      body = `Your appointment has been updated to ${newTime}.`;
      logger.info("📝 Appointment date/time or note changed.");
    }

    // 🚀 Send notification if applicable
    if (title && body) {
      try {
        await messaging.send({
          token: fcmToken,
          notification: {
            title,
            body,
          },
        });
        logger.info("✅ Notification sent successfully.");
      } catch (error) {
        logger.error("❌ Error sending notification", error);
      }
    } else {
      logger.info("ℹ️ No significant appointment changes to notify.");
    }
  }
);
