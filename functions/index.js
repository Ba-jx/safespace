const functions = require("firebase-functions/v2");
const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");
const sgMail = require("@sendgrid/mail");

// 🔐 Use secret key set with: firebase functions:secrets:set SENDGRID_API_KEY
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

// 🔧 Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// ✅ Test HTTP function
exports.helloWorld = onRequest((req, res) => {
  logger.info("Hello logs!", { structuredData: true });
  res.send("Hello from Firebase!");
});

// 🔔 Notify patient when appointment is updated
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
      logger.warn(`❌ No FCM token found for user ${userId}. Notification skipped.`);
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
      logger.info("📝 Appointment date/time or note changed.");
    }

    if (title && body) {
      try {
        await messaging.send({
          token: fcmToken,
          notification: { title, body },
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

// 📧 Email confirmation for new appointment creation
exports.sendAppointmentConfirmationEmail = onDocumentCreated(
  {
    document: "users/{userId}/appointments/{appointmentId}",
    region: "us-central1",
  },
  async (event) => {
    const { userId } = event.params;
    const appointment = event.data.data();

    const userDoc = await db.collection("users").doc(userId).get();
    const email = userDoc.exists ? userDoc.data().email : null;

    if (!email) {
      logger.warn(`⚠️ No email for patient ${userId}. Email skipped.`);
      return;
    }

    const dateTime = appointment.dateTime.toDate().toLocaleString();
    const note = appointment.note || "No notes";

    const msg = {
      to: email,
      from: "bayanismail302@gmail.com", // ✅ Use verified Gmail sender for testing
      subject: "Your Appointment is Confirmed",
      text: `Dear Patient,\n\nYour appointment has been successfully booked.\n\n📅 Date: ${dateTime}\n📝 Note: ${note}\n\nThank you,\nSafe Space Team`,
    };

    try {
      await sgMail.send(msg);
      logger.info(`📧 Confirmation email sent to ${email}`);
    } catch (error) {
      logger.error("❌ Failed to send confirmation email:", error);
    }
  }
);

// ⏰ Daily symptom reminder at 9:50 PM Jordan Time (18:50 UTC)
exports.dailySymptomReminder = onSchedule(
  {
    schedule: "50 18 * * *",
    timeZone: "Asia/Amman",
  },
  async () => {
    logger.info("⏰ Running daily symptom reminder");

    const patientsSnapshot = await db
      .collection("users")
      .where("role", "==", "patient")
      .get();

    const messagingPromises = [];

    patientsSnapshot.forEach((doc) => {
      const data = doc.data();
      if (data.fcmToken) {
        logger.info(
          `Reminder queued for patientId="${doc.id}", name="${data.name || "N/A"}", email="${data.email || "N/A"}"`
        );

        messagingPromises.push(
          messaging.send({
            token: data.fcmToken,
            notification: {
              title: "Daily Symptom Check-in",
              body: "Please remember to log your symptoms today.",
            },
          })
        );
      } else {
        logger.warn(`No FCM token for patientId="${doc.id}"`);
      }
    });

    await Promise.all(messagingPromises);
    logger.info(`📨 Sent ${messagingPromises.length} daily reminders.`);
  }
);
