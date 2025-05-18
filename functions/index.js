const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");
const sgMail = require("@sendgrid/mail");

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// ✅ Notify on appointment update or cancel
exports.notifyAppointmentChanged = onDocumentUpdated({
  document: "users/{userId}/appointments/{appointmentId}",
  region: "us-central1",
  secrets: ["SENDGRID_API_KEY"],
}, async (event) => {
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);
  logger.info("✅ notifyAppointmentChanged triggered");

  const before = event.data.before.data();
  const after = event.data.after.data();
  const userId = event.params.userId;

  const userDoc = await db.collection("users").doc(userId).get();
  const fcmToken = userDoc.exists && userDoc.data().fcmToken;
  const email = userDoc.exists ? userDoc.data().email : null;
  const name = userDoc.exists ? userDoc.data().name || "Patient" : "Patient";

  const formattedDate = after.dateTime.toDate().toLocaleString("en-US", {
    timeZone: "Asia/Amman",
    weekday: "long", year: "numeric", month: "long", day: "numeric",
    hour: "2-digit", minute: "2-digit"
  });

  let title = "";
  let body = "";
  let emailSubject = "";
  let emailBody = "";

  if (before.status !== after.status) {
    if (after.status.toLowerCase() === "cancelled") {
      title = "Appointment Canceled";
      body = "Your appointment has been cancelled.";
      emailSubject = "Your Appointment Has Been Cancelled";
      emailBody = `Dear ${name},\n\nYour appointment on ${formattedDate} has been cancelled.\n\nSafe Space Team`;
    } else {
      title = "Appointment Status Updated";
      body = `Your appointment status changed to "${after.status}".`;
      emailSubject = "Appointment Status Changed";
      emailBody = `Dear ${name},\n\nYour appointment status has been updated to "${after.status}".\n📅 ${formattedDate}\n\nThank you,\nSafe Space Team`;
    }
  } else if (
    before.note !== after.note ||
    before.dateTime.toMillis() !== after.dateTime.toMillis()
  ) {
    title = "Appointment Updated";
    body = `Your appointment has been updated to ${formattedDate}.`;
  }

  if (title && body && fcmToken) {
    try {
      await messaging.send({
        token: fcmToken,
        notification: { title, body },
      });
      logger.info("✅ FCM notification sent");
    } catch (error) {
      logger.error("❌ FCM send error", error);
    }
  }

  if (email && emailSubject && emailBody) {
    try {
      await sgMail.send({
        to: email,
        from: "bayanismail302@gmail.com",
        subject: emailSubject,
        text: emailBody,
      });
      logger.info(`📧 Email sent to ${email}`);
    } catch (error) {
      logger.error("❌ Email send error", error);
    }
  }
});

// ✅ Daily symptom reminder at 7:00 PM
exports.dailySymptomReminder = onSchedule({
  schedule: "0 19 * * *", // 7:00 PM
  timeZone: "Asia/Amman",
}, async () => {
  logger.info("⏰ Running daily symptom reminder");

  const patientsSnapshot = await db.collection("users")
    .where("role", "==", "patient")
    .get();

  const sendTasks = [];

  patientsSnapshot.forEach((doc) => {
    const data = doc.data();
    if (data.fcmToken) {
      sendTasks.push(
        messaging.send({
          token: data.fcmToken,
          notification: {
            title: "🩺 Daily Symptom Check-in",
            body: "Don't forget to track your symptoms today.",
          },
        })
      );
    }
  });

  await Promise.all(sendTasks);
  logger.info(`📨 Sent ${sendTasks.length} symptom reminders.`);
});

// ✅ Tomorrow’s confirmed appointment reminder (with times)
exports.appointmentReminderForNextDay = onSchedule({
  schedule: "0 16 * * *", // 4:00 PM
  timeZone: "Asia/Amman",
}, async () => {
  logger.info("📅 Running next-day appointment reminders");

  const now = new Date();
  const startOfTomorrow = new Date(now);
  startOfTomorrow.setDate(now.getDate() + 1);
  startOfTomorrow.setHours(0, 0, 0, 0);

  const startOfDayAfterTomorrow = new Date(startOfTomorrow);
  startOfDayAfterTomorrow.setDate(startOfTomorrow.getDate() + 1);

  const lower = Timestamp.fromDate(startOfTomorrow);
  const upper = Timestamp.fromDate(startOfDayAfterTomorrow);

  const snapshot = await db
    .collectionGroup("appointments")
    .where("status", "==", "confirmed")
    .where("dateTime", ">=", lower)
    .where("dateTime", "<", upper)
    .get();

  if (snapshot.empty) {
    logger.info("ℹ️ No appointments for tomorrow.");
    return;
  }

  const appointmentsByPatient = new Map();

  snapshot.docs.forEach((doc) => {
    const userId = doc.ref.path.split("/")[1];
    const time = doc.data().dateTime.toDate().toLocaleTimeString("en-US", {
      timeZone: "Asia/Amman",
      hour: "2-digit",
      minute: "2-digit"
    });

    if (!appointmentsByPatient.has(userId)) {
      appointmentsByPatient.set(userId, []);
    }
    appointmentsByPatient.get(userId).push(time);
  });

  const sendPromises = [];

  for (const [userId, times] of appointmentsByPatient.entries()) {
    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.exists && userDoc.data().fcmToken;
    const name = userDoc.exists ? userDoc.data().name || "Patient" : "Patient";

    if (!fcmToken) continue;

    const formattedTimes = times.join(", ");
    logger.info(`🔔 Notifying ${name}: ${formattedTimes}`);

    sendPromises.push(
      messaging.send({
        token: fcmToken,
        notification: {
          title: "📅 Tomorrow’s Appointments",
          body: `You have appointments tomorrow at: ${formattedTimes}`,
        },
      })
    );
  }

  await Promise.all(sendPromises);
  logger.info(`✅ Sent ${sendPromises.length} next-day appointment reminders.`);
});

// ✅ Delete stale pending appointments (older than 24h)
exports.deleteStalePendingAppointments = onSchedule({
  schedule: "every 30 minutes",
  timeZone: "Asia/Amman",
}, async () => {
  logger.info("🧹 Checking for stale pending appointments...");

  const now = Timestamp.now();
  const twentyFourHoursAgo = Timestamp.fromMillis(now.toMillis() - 24 * 60 * 60 * 1000);

  try {
    const snapshot = await db
      .collectionGroup("appointments")
      .where("status", "==", "pending")
      .where("dateTime", "<", twentyFourHoursAgo)
      .get();

    if (snapshot.empty) {
      logger.info("ℹ️ No stale pending appointments found.");
      return;
    }

    const batch = db.batch();
    snapshot.forEach((doc) => {
      batch.delete(doc.ref);
      logger.info(`🗑️ Deleted pending appointment: ${doc.id}`);
    });

    await batch.commit();
    logger.info(`✅ Deleted ${snapshot.size} stale pending appointments.`);
  } catch (error) {
    logger.error("❌ Error deleting stale pending appointments:", error);
  }
});

// ✅ Automatically mark past confirmed appointments as completed
exports.markPastAppointmentsAsCompleted = onSchedule({
  schedule: "every 30 minutes",
  timeZone: "Asia/Amman",
}, async () => {
  logger.info("🔁 Running appointment completion check...");

  const now = Timestamp.now();

  try {
    const snapshot = await db
      .collectionGroup("appointments")
      .where("status", "==", "confirmed")
      .where("dateTime", "<", now)
      .get();

    if (snapshot.empty) {
      logger.info("ℹ️ No appointments to mark as completed.");
      return;
    }

    const batch = db.batch();
    snapshot.forEach((doc) => {
      batch.update(doc.ref, { status: "completed" });
      logger.info(`✅ Marked appointment as completed: ${doc.id}`);
    });

    await batch.commit();
    logger.info(`✅ Completed ${snapshot.size} appointments.`);
  } catch (error) {
    logger.error("❌ Error marking appointments as completed:", error);
  }
});
