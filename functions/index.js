const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
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

// ✅ Notify on appointment update or cancel (FCM only)
exports.notifyAppointmentChanged = onDocumentUpdated({
  document: "users/{userId}/appointments/{appointmentId}",
  region: "us-central1",
}, async (event) => {
  logger.info("✅ notifyAppointmentChanged triggered");

  const before = event.data.before.data();
  const after = event.data.after.data();
  const userId = event.params.userId;

  const userDoc = await db.collection("users").doc(userId).get();
  const fcmToken = userDoc.exists && userDoc.data().fcmToken;
  const name = userDoc.exists ? userDoc.data().name || "Patient" : "Patient";

  const formattedDate = after.dateTime.toDate().toLocaleString("en-US", {
    timeZone: "Asia/Amman",
    weekday: "long", year: "numeric", month: "long", day: "numeric",
    hour: "2-digit", minute: "2-digit"
  });

  let title = "";
  let body = "";

  if (before.status !== after.status) {
    if (after.status.toLowerCase() === "cancelled") {
      title = "Appointment Canceled";
      body = "Your appointment has been cancelled.";
    } else {
      title = "Appointment Status Updated";
      body = `Your appointment status changed to "${after.status}".`;
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
});

// ✅ Daily symptom reminder at 7:00 PM
exports.dailySymptomReminder = onSchedule({
  schedule: "0 19 * * *",
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

// ✅ Tomorrow’s confirmed appointment reminder (with times) at 6:00 PM
exports.appointmentReminderForNextDay = onSchedule({
  schedule: "0 18 * * *",
  timeZone: "Asia/Amman",
}, async () => {
  logger.info("📅 Running next-day appointment reminders (6 PM)");

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
    logger.info("ℹ️ No confirmed appointments for tomorrow.");
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
          body: `You have confirmed appointments tomorrow at: ${formattedTimes}`,
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

// ✅ Send email digest if unread notification count ≥ 3
exports.sendUnreadNotificationDigest = onSchedule({
  schedule: "30 18 * * *", // 6:30 PM
  timeZone: "Asia/Amman",
  secrets: ["SENDGRID_API_KEY"],
}, async () => {
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);
  logger.info("📨 Running unread notification digest");

  const usersSnapshot = await db.collection("users")
    .where("role", "==", "patient")
    .get();

  const sendTasks = [];

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const userData = userDoc.data();

    const notificationsSnapshot = await db
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .where("read", "==", false)
      .where("digestSent", "==", false)
      .get();

    if (notificationsSnapshot.empty || notificationsSnapshot.size < 3) continue;

    const messages = notificationsSnapshot.docs.map((doc) => {
      const n = doc.data();
      const time = n.timestamp?.toDate().toLocaleString("en-US", {
        timeZone: "Asia/Amman",
        hour: "2-digit",
        minute: "2-digit",
        day: "2-digit",
        month: "short",
        year: "numeric",
      }) || "Unknown Time";

      return `🕒 ${time}\n🔔 ${n.title}\n${n.body}`;
    }).join("\n\n");

    const emailContent = `
Dear ${userData.name || "Patient"},

You have ${notificationsSnapshot.size} unread notifications in your Safe Space app.

Here is a summary of your recent notifications:

${messages}

👉 [Open Safe Space App](https://your-app-link.com/open)

Please log into the app to read or respond.

– Safe Space Team
`.trim();

    if (userData.email) {
      const sendTask = sgMail.send({
        to: userData.email,
        from: "bayanismail302@gmail.com",
        subject: "📬 You Have Unread Notifications – Safe Space Digest",
        text: emailContent,
      });

      sendTasks.push(sendTask);

      const batch = db.batch();
      notificationsSnapshot.docs.forEach((doc) => {
        batch.update(doc.ref, { digestSent: true });
      });
      await batch.commit();

      logger.info(`📧 Digest sent and marked for ${userData.email}`);
    }
  }

  await Promise.all(sendTasks);
  logger.info(`✅ Digest emails processed: ${sendTasks.length}`);
});
