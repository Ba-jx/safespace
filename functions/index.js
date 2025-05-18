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

// ✅ Appointment update/cancel notification
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

// ✅ Daily symptom reminder (7 PM)
exports.dailySymptomReminder = onSchedule({
  schedule: "0 19 * * *",
  timeZone: "Asia/Amman",
}, async () => {
  const patients = await db.collection("users").where("role", "==", "patient").get();

  const sendTasks = [];

  for (let i = 0; i < patients.docs.length; i++) {
    const data = patients.docs[i].data();
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
  }

  await Promise.all(sendTasks);
});

// ✅ Tomorrow’s confirmed appointment reminder (6 PM)
exports.appointmentReminderForNextDay = onSchedule({
  schedule: "0 18 * * *",
  timeZone: "Asia/Amman",
}, async () => {
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(now.getDate() + 1);
  tomorrow.setHours(0, 0, 0, 0);

  const afterTomorrow = new Date(tomorrow);
  afterTomorrow.setDate(tomorrow.getDate() + 1);

  const lower = Timestamp.fromDate(tomorrow);
  const upper = Timestamp.fromDate(afterTomorrow);

  const snapshot = await db.collectionGroup("appointments")
    .where("status", "==", "confirmed")
    .where("dateTime", ">=", lower)
    .where("dateTime", "<", upper)
    .get();

  const byPatient = {};

  for (let i = 0; i < snapshot.docs.length; i++) {
    const doc = snapshot.docs[i];
    const userId = doc.ref.path.split("/")[1];
    const time = doc.data().dateTime.toDate().toLocaleTimeString("en-US", {
      timeZone: "Asia/Amman",
      hour: "2-digit", minute: "2-digit"
    });

    if (!byPatient[userId]) byPatient[userId] = [];
    byPatient[userId].push(time);
  }

  for (const userId in byPatient) {
    const times = byPatient[userId];
    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.exists && userDoc.data().fcmToken;
    const title = "📅 Tomorrow’s Appointments";
    const body = `You have confirmed appointments tomorrow at: ${times.join(", ")}`;

    await createNotification(userId, title, body);

    if (fcmToken) {
      await messaging.send({ token: fcmToken, notification: { title, body } });
    }
  }
});

// ✅ Digest email for unread notifications
exports.sendUnreadNotificationDigest = onSchedule({
  schedule: "30 18 * * *",
  timeZone: "Asia/Amman",
  secrets: ["SENDGRID_API_KEY"],
}, async () => {
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);

  const users = await db.collection("users").where("role", "==", "patient").get();

  for (let i = 0; i < users.docs.length; i++) {
    const userDoc = users.docs[i];
    const userId = userDoc.id;
    const userData = userDoc.data();

    const notifs = await db.collection("users").doc(userId).collection("notifications")
      .where("read", "==", false)
      .where("digestSent", "==", false)
      .get();

    if (notifs.size < 3) continue;

    const content = notifs.docs.map(doc => {
      const n = doc.data();
      const time = n.timestamp?.toDate().toLocaleString("en-US", {
        timeZone: "Asia/Amman",
        hour: "2-digit", minute: "2-digit", day: "2-digit", month: "short", year: "numeric",
      }) || "Unknown Time";
      return `🕒 ${time}\n🔔 ${n.title}\n${n.body}`;
    }).join("\n\n");

    const emailText = `
Dear ${userData.name || "Patient"},

You have ${notifs.size} unread notifications in your Safe Space app.

Here is a summary:

${content}

👉 [Open Safe Space App](https://your-app-link.com/open)

– Safe Space Team
    `.trim();

    if (userData.email) {
      await sgMail.send({
        to: userData.email,
        from: "bayanismail302@gmail.com",
        subject: "📬 You Have Unread Notifications – Safe Space Digest",
        text: emailText,
      });

      const batch = db.batch();
      notifs.docs.forEach(doc => batch.update(doc.ref, { digestSent: true }));
      await batch.commit();
    }
  }
});

// ✅ Delete stale pending appointments
exports.deleteStalePendingAppointments = onSchedule({
  schedule: "every 30 minutes",
  timeZone: "Asia/Amman",
}, async () => {
  const now = Timestamp.now();
  const expired = Timestamp.fromMillis(now.toMillis() - 24 * 60 * 60 * 1000);

  const snapshot = await db.collectionGroup("appointments")
    .where("status", "==", "pending")
    .where("dateTime", "<", expired)
    .get();

  const batch = db.batch();
  snapshot.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
});

// ✅ Auto-complete past confirmed appointments
exports.markPastAppointmentsAsCompleted = onSchedule({
  schedule: "every 30 minutes",
  timeZone: "Asia/Amman",
}, async () => {
  const now = Timestamp.now();

  const snapshot = await db.collectionGroup("appointments")
    .where("status", "==", "confirmed")
    .where("dateTime", "<", now)
    .get();

  const batch = db.batch();
  snapshot.forEach(doc => batch.update(doc.ref, { status: "completed" }));
  await batch.commit();
});
