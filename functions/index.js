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
    logger.info("🔥 Function triggered for appointment update");

    const before = event.data.before.data();
    const after = event.data.after.data();
    const userId = event.params.userId;

    logger.info("👤 User ID:", userId);
    logger.info("🕒 Before status:", before.status);
    logger.info("🕒 After status:", after.status);

    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.exists && userDoc.data().fcmToken;

    logger.info("📱 FCM Token:", fcmToken);

    if (!fcmToken) {
      logger.warn("⚠️ No FCM token found for user");
      return;
    }

    let title = "";
    let body = "";

    if (before.status !== after.status) {
      title = "Appointment Status Updated";
      body = `Your appointment status changed to "${after.status}".`;
      logger.info("🔄 Status changed:", body);
    } else if (
      before.note !== after.note ||
      before.dateTime.toMillis() !== after.dateTime.toMillis()
    ) {
      const newTime = after.dateTime.toDate().toLocaleString();
      title = "Appointment Updated";
      body = `Your appointment has been updated to ${newTime}.`;
      logger.info("📝 Note or Date changed:", body);
    } else {
      logger.info("ℹ️ No relevant changes to notify.");
      return;
    }

    try {
      const response = await messaging.send({
        token: fcmToken,
        notification: {
          title,
          body,
        },
      });
      logger.info("✅ Notification sent:", response);
    } catch (error) {
      logger.error("❌ Failed to send notification:", error);
    }
  }
);
