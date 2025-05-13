const functions = require("firebase-functions/v2");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

// 🔧 Initialize Firebase Admin SDK
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// ✅ Simple test function
exports.helloWorld = onRequest((req, res) => {
  logger.info("Hello logs!", { structuredData: true });
  res.send("Hello from Firebase!");
});

// 🔔 Triggered when an appointment document is updated
exports.notifyAppointmentChanged = onDocumentUpdated(
  {
    document: "users/{userId}/appointments/{appointmentId}",
    region: "us-central1",
  },
  async (event) => {
    logger.info("✅ notifyAppointmentChanged function triggered");

    const before = event.data.before.data();
    const after = event.data.after.data();

    const userId = event.params.userId;
    logger.info(`📍 Processing changes for user: ${userId}`);

    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.exists && userDoc.data().fcmToken;

    if (!fcmToken) {
      logger.warn(`❌ No FCM token for user ${userId}. Notification skipped.`);
      return;
    }

    let title = "";
    let body = "";

    if (before.status !== after.status) {
      title = "Appointment Status Updated";
      body = `Your appointment status changed to "${after.status}".`;
      logger.info(`🔄 Status changed to: ${after.status}`);
    } else if (
      before.note !== after.note ||
      before.dateTime.toMillis() !== after.dateTime.toMillis()
    ) {
      const newTime = after.dateTime.toDate().toLocaleString();
      title = "Appointment Updated";
      body = `Your appointment has been updated to ${newTime}.`;
      logger.info("📝 Appointment note or date/time changed.");
    }

    if (title && body) {
      try {
        await messaging.send({
          token: fcmToken,
          notification: { title, body },
        });
        logger.info(`✅ Notification sent to patientId: ${userId}`);
      } catch (error) {
        logger.error("❌ Error sending notification", error);
      }
    } else {
      logger.info("ℹ️ No significant appointment changes to notify.");
    }
  }
);

// ⏰ Daily reminder to log symptoms (9:05 PM Jordan Time)
exports.dailySymptomReminder = onSchedule(
  {
    schedule: "5 18 * * *", // 18:05 UTC = 9:05 PM Asia/Amman
    timeZone: "Asia/Amman",
  },
  async () => {
    logger.info("⏰ Running daily symptom reminder...");

    const snapshot = await db
      .collection("users")
      .where("role", "==", "patient")
      .get();

    const tasks = [];

    snapshot.forEach((doc) => {
      const data = doc.data();

      if (data.fcmToken) {
        const name = data.name || "N/A";
        const email = data.email || "N/A";

        logger.info(
          `🔔 Reminder queued for patientId: ${doc.id}, name: ${name}, email: ${email}`
        );

        tasks.push(
          messaging.send({
            token: data.fcmToken,
            notification: {
              title: "Daily Symptom Check-in",
              body: "Please remember to log your symptoms today.",
            },
          })
        );
      } else {
        logger.warn(`⚠️ No FCM token for patientId: ${doc.id}`);
      }
    });

    await Promise.all(tasks);
    logger.info(`📨 Sent ${tasks.length} daily symptom reminders.`);
  }
);
