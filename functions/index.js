const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");
const sgMail = require("@sendgrid/mail");

// Initialize Firebase Admin SDK
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// ✅ HTTP test function
exports.helloWorld = onRequest({
  region: "us-central1",
  platform: "gcfv1",
}, (req, res) => {
  logger.info("Hello logs!", { structuredData: true });
  res.send("Hello from Firebase!");
});

// ✅ Notify patient about appointment update or cancel
exports.notifyAppointmentChanged = onDocumentUpdated({
  document: "users/{userId}/appointments/{appointmentId}",
  region: "us-central1",
  platform: "gcfv1",
  secrets: ["SENDGRID_API_KEY"],
}, async (event) => {
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);

  const before = event.data.before.data();
  const after = event.data.after.data();

  // Send only if status changed
  if (before.status !== after.status) {
    const userId = event.params.userId;
    const userDoc = await db.collection("users").doc(userId).get();
    const user = userDoc.data();

    const msg = {
      to: user.email,
      from: after.doctorEmail || "no-reply@safespace.com",
      subject: "Appointment Status Updated",
      text: `Your appointment on ${new Date(after.dateTime._seconds * 1000).toLocaleString()} is now "${after.status}".`,
    };

    await sgMail.send(msg);
    logger.info("📧 Email sent to", user.email);
  }
});

// ✅ Daily symptom reminder at 4 PM
exports.dailySymptomReminder = onSchedule({
  schedule: "every day 16:00",
  timeZone: "Asia/Amman",
  region: "us-central1",
  platform: "gcfv1",
}, async () => {
  const usersSnapshot = await db.collection("users").get();

  for (const doc of usersSnapshot.docs) {
    const user = doc.data();
    if (user.fcmToken) {
      await messaging.send({
        token: user.fcmToken,
        notification: {
          title: "Daily Check-In Reminder",
          body: "Please log your symptoms in Safe Space today.",
        },
      });
    }
  }

  logger.info("✅ Daily reminders sent");
});

// ✅ Reminder 24 hours before confirmed appointment
exports.appointmentReminderForNextDay = onSchedule({
  schedule: "every day 16:00",
  timeZone: "Asia/Amman",
  region: "us-central1",
  platform: "gcfv1",
}, async () => {
  const tomorrow = Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000));
  const snapshot = await db.collectionGroup("appointments")
    .where("status", "==", "confirmed")
    .get();

  for (const doc of snapshot.docs) {
    const appointment = doc.data();
    const time = appointment.dateTime;

    if (
      Math.abs(time.seconds - tomorrow.seconds) < 3600 * 3 // ±3h window
    ) {
      const userRef = doc.ref.parent.parent;
      const userSnap = await userRef.get();
      const user = userSnap.data();

      if (user.fcmToken) {
        await messaging.send({
          token: user.fcmToken,
          notification: {
            title: "Appointment Reminder",
            body: `You have an appointment tomorrow at ${new Date(time.seconds * 1000).toLocaleTimeString()}.`,
          },
        });
      }
    }
  }

  logger.info("✅ 24-hour appointment reminders sent");
});

// ✅ Delete pending appointments older than 48 hours
exports.deleteStalePendingAppointments = onSchedule({
  schedule: "every 6 hours",
  timeZone: "Asia/Amman",
  region: "us-central1",
  platform: "gcfv1",
}, async () => {
  const threshold = Timestamp.fromDate(new Date(Date.now() - 48 * 3600 * 1000));
  const snapshot = await db.collectionGroup("appointments")
    .where("status", "==", "pending")
    .get();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (data.createdAt && data.createdAt.toDate() < threshold.toDate()) {
      await doc.ref.delete();
      logger.info(`🗑️ Deleted stale pending appointment: ${doc.id}`);
    }
  }
});

// ✅ Auto-complete past confirmed appointments
exports.markPastAppointmentsAsCompleted = onSchedule({
  schedule: "every 6 hours",
  timeZone: "Asia/Amman",
  region: "us-central1",
  platform: "gcfv1",
}, async () => {
  const now = Timestamp.now();
  const snapshot = await db.collectionGroup("appointments")
    .where("status", "==", "confirmed")
    .where("dateTime", "<", now)
    .get();

  for (const doc of snapshot.docs) {
    await doc.ref.update({ status: "completed" });
    logger.info(`✅ Marked appointment as completed: ${doc.id}`);
  }
});

// ✅ Digest notification of unread messages daily
exports.sendUnreadNotificationDigest = onSchedule({
  schedule: "every day 17:00",
  timeZone: "Asia/Amman",
  region: "us-central1",
  platform: "gcfv1",
}, async () => {
  const userDocs = await db.collection("users").get();

  for (const doc of userDocs.docs) {
    const user = doc.data();
    const chatsSnapshot = await db
      .collection(`messages/${doc.id}/chats`)
      .where("isRead", "==", false)
      .get();

    const unreadCount = chatsSnapshot.size;
    if (unreadCount > 0 && user.fcmToken) {
      await messaging.send({
        token: user.fcmToken,
        notification: {
          title: "Unread Messages",
          body: `You have ${unreadCount} unread messages. Open Safe Space to check them.`,
        },
      });
    }
  }

  logger.info("📨 Unread message digests sent");
});
