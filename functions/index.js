const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");
const sgMail = require("@sendgrid/mail");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// ✅ Reusable: Create Firestore notification
async function createNotification(userId, title, body) {
  const notifRef = db
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .doc();

  await notifRef.set({
    title,
    body,
    timestamp: Timestamp.now(),
    read: false,
    digestSent: false,
  });

  logger.info(`🔔 Notification created for user: ${userId}`);
}

// ✅ Notify on appointment update or cancel (FCM + Firestore)
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

  if (title && body) {
    // 🔔 Save notification in Firestore
    await createNotification(userId, title, body);

    // 📲 Send FCM if available
    if (fcmToken) {
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

// ✅ Tomorrow’s confirmed appointment reminder (FCM) at 6:00 PM
exports.appointmentReminderForNextDay = onSchedule({
  schedule: "0 18 * * *",
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

    const formattedTimes = times.join(", ");
    const title = "📅 Tomorrow’s Appointments";
    const body = `You have confirmed appointments tomorrow at: ${formattedTimes}`;

    // 🔔 Create Firestore notification
    await createNotification(userId, title, body);

    // 📲 FCM
    if (fcmToken) {
      sendPromises.push(
        messaging.send({
          token: fcmToken,
          notification: { title, body },
        })
      );
    }
  }

  await Promise.all(sendPromises);
  logger.info(`✅ Sent ${sendPromises.length} next-day reminders.`);
});

// ✅ Email digest for unread notifications ≥ 3
exports.sendUnreadNotificationDigest = onSchedule({
  schedule: "30 18 * * *",
  timeZone: "Asia/Amman",
  secrets: ["SENDGRID_API_KEY"],
}, async () => {
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);
  logger.info("📬 Running unread notification digest");

  const usersSnapshot = await db.collection("users")
    .where("role", "==", "patient")
    .get();

  const sendTasks = [];

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const userData = userDoc.data();

    const notifSnapshot = await db
      .collection("users").doc(userId)
      .collection("notifications")
      .where("read", "==", false)
      .where("digestSent", "==", false)
      .get();

    if (notifSnapshot.size < 3) continue;

    const messages = notifSnapshot.docs.map((doc) => {
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

You have ${notifSnapshot.size} unread notifications in your Safe Space app.

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

      // ✅ Mark all included as sent
      const batch = db.batch();
      notifSnapshot.docs.forEach((doc) => {
        batch.update(doc.ref, { digestSent: true });
      });
      await batch.commit();

      logger.info(`📧 Digest sent to ${userData.email}`);
    }
  }

  await Promise.all(sendTasks);
  logger.info(`✅ Digest emails processed: ${sendTasks.length}`);
});

// ✅ Delete stale pending appointments (older than 24h)
exports.deleteStalePendingAppointments = onSchedule({
  schedule: "every 30 minutes",
  timeZone: "Asia/Amman",
}, async () => {
  logger.info("🧹 Checking for stale pending appointments...");

  const now = Timestamp.now();
  const expired = Timestamp.fromMillis(now.toMillis() - 24 * 60 * 60 * 1000);

  const snapshot = await db
    .collectionGroup("appointments")
    .where("status", "==", "pending")
    .where("dateTime", "<", expired)
    .get();

  if (snapshot.empty) {
    logger.info("ℹ️ No stale appointments.");
    return;
  }

  const batch = db.batch();
  snapshot.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  logger.info(`✅ Deleted ${snapshot.size} stale pending appointments.`);
});

// ✅ Auto-complete confirmed appointments in the past
exports.markPastAppointmentsAsCompleted = onSchedule({
  schedule: "every 30 minutes",
  timeZone: "Asia/Amman",
}, async () => {
  logger.info("🔁 Running appointment completion check...");

  const now = Timestamp.now();

  const snapshot = await db
    .collectionGroup("appointments")
    .where("status", "==", "confirmed")
    .where("dateTime", "<", now)
    .get();

  if (snapshot.empty) {
    logger.info("ℹ️ No appointments to complete.");
    return;
  }

  const batch = db.batch();
  snapshot.forEach((doc) => {
    batch.update(doc.ref, { status: "completed" });
  });

  await batch.commit();
  logger.info(`✅ Marked ${snapshot.size} appointments as completed.`);
});
