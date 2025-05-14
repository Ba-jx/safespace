const functions = require("firebase-functions/v2");
const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");
const sgMail = require("@sendgrid/mail");

// 🔧 Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// ✅ Test HTTP function
exports.helloWorld = onRequest((req, res) => {
  logger.info("Hello logs!", { structuredData: true });
  res.send("Hello from Firebase!");
});

// 🔔 Notify patient when appointment is updated (includes cancellation email)
exports.notifyAppointmentChanged = onDocumentUpdated(
  {
    document: "users/{userId}/appointments/{appointmentId}",
    region: "us-central1",
    secrets: ["SENDGRID_API_KEY"], // ✅ Secret binding
  },
  async (event) => {
    sgMail.setApiKey(process.env.SENDGRID_API_KEY);

    logger.info("✅ notifyAppointmentChanged function triggered");

    const before = event.data.before.data();
    const after = event.data.after.data();
    const userId = event.params.userId;

    logger.info(`📍 Processing changes for user: ${userId}`);
    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.exists && userDoc.data().fcmToken;
    const email = userDoc.exists ? userDoc.data().email : null;

    if (!fcmToken) {
      logger.warn(`❌ No FCM token found for user ${userId}. Notification skipped.`);
    }

    const dateTimeFormatted = after.dateTime.toDate().toLocaleString("en-US", {
      timeZone: "Asia/Amman",
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });

    let title = "";
    let body = "";
    let emailSubject = "";
    let emailBody = "";

    if (before.status !== after.status) {
      logger.info(`🔄 Status changed to: ${after.status}`);

      if (after.status.toLowerCase() === "canceled") {
        title = "Appointment Canceled";
        body = "Your appointment has been canceled.";
        emailSubject = "Appointment Cancellation Notice";
        emailBody = `Dear Patient,\n\nWe regret to inform you that your appointment on ${dateTimeFormatted} has been canceled.\n\nThank you,\nSafe Space Team`;
      } else {
        title = "Appointment Status Updated";
        body = `Your appointment status changed to "${after.status}".`;
        emailSubject = "Appointment Status Changed";
        emailBody = `Dear Patient,\n\nYour appointment status has changed to "${after.status}".\n\nDate: ${dateTimeFormatted}\n\nThank you,\nSafe Space Team`;
      }
    } else if (
      before.note !== after.note ||
      before.dateTime.toMillis() !== after.dateTime.toMillis()
    ) {
      title = "Appointment Updated";
      body = `Your appointment has been updated to ${dateTimeFormatted}.`;
    }

    if (title && body && fcmToken) {
      try {
        await messaging.send({
          token: fcmToken,
          notification: { title, body },
        });
        logger.info("✅ Notification sent successfully.");
      } catch (error) {
        logger.error("❌ Error sending FCM notification", error);
      }
    }

    if (email && emailSubject && emailBody) {
      try {
        await sgMail.send({
          to: email,
          from: "bayanismail302@gmail.com", // ✅ Verified sender
          subject: emailSubject,
          text: emailBody,
        });
        logger.info(`📧 Email sent to ${email}`);
      } catch (error) {
        logger.error("❌ Failed to send email:", error);
      }
    } else {
      logger.info("ℹ️ No email sent (no status change or email missing)");
    }
  }
);

// 📧 Email confirmation for new appointment creation
exports.sendAppointmentConfirmationEmail = onDocumentCreated(
  {
    document: "users/{userId}/appointments/{appointmentId}",
    region: "us-central1",
    secrets: ["SENDGRID_API_KEY"],
  },
  async (event) => {
    sgMail.setApiKey(process.env.SENDGRID_API_KEY);

    const { userId } = event.params;
    const appointment = event.data.data();

    const userDoc = await db.collection("users").doc(userId).get();
    const email = userDoc.exists ? userDoc.data().email : null;

    if (!email) {
      logger.warn(`⚠️ No email for patient ${userId}. Email skipped.`);
      return;
    }

    const dateTime = appointment.dateTime.toDate().toLocaleString("en-US", {
      timeZone: "Asia/Amman",
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });

    const note = appointment.note || "No notes";

    const msg = {
      to: email,
      from: "bayanismail302@gmail.com", // ✅ Verified sender
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

// ⏰ Daily symptom reminder at 9:50 PM Jordan Time
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
