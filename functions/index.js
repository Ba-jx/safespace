const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
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
  const notifRef = db.collection("users").doc(userId).collection("notifications").doc();
  await notifRef.set({
    title,
    body,
    timestamp: Timestamp.now(),
    read: false,
    digestSent: false,
  });
  logger.info(`🔔 Notification created for user: ${userId}`);
}

// ✅ Real-time FCM for new messages (doctor → patient only)
exports.notifyNewMessage = onDocumentCreated({
  document: "messages/{chatId}/chats/{messageId}",
  region: "us-central1",
  platform: "gcfv1",
}, async (event) => {
  const message = event.data.data();
  const chatId = event.params.chatId;
  const [userA, userB] = chatId.split("_");
  const recipientId = message.senderId === userA ? userB : userA;

  const senderDoc = await db.collection("users").doc(message.senderId).get();
  const recipientDoc = await db.collection("users").doc(recipientId).get();

  const sender = senderDoc.data();
  const recipient = recipientDoc.data();

  if (
    recipient.role === "patient" &&
    recipient.doctorId === message.senderId &&
    recipient.fcmToken
  ) {
    const title = "New Message from Your Doctor";
    const body = `${sender.name || "Doctor"}: ${message.text || "Sent a message"}`;
    await messaging.send({
      token: recipient.fcmToken,
      notification: { title, body },
    });
    logger.info(`📨 Message notification sent to patient ${recipientId}`);
  }
});

// ✅ Daily unread message digest (patients only)
exports.sendUnreadMessageDigest = onSchedule({
  schedule: "0 17 * * *",
  timeZone: "Asia/Amman",
  region: "us-central1",
  platform: "gcfv1",
}, async () => {
  const patients = await db.collection("users").where("role", "==", "patient").get();

  for (const patientDoc of patients.docs) {
    const patient = patientDoc.data();
    const patientId = patientDoc.id;

    if (!patient.fcmToken || !patient.doctorId) continue;

    const chatsSnapshot = await db
      .collection(`messages/${patientId}/chats`)
      .where("isRead", "==", false)
      .get();

    let countFromDoctor = 0;
    for (const chat of chatsSnapshot.docs) {
      const data = chat.data();
      if (data.senderId === patient.doctorId) {
        countFromDoctor++;
      }
    }

    if (countFromDoctor > 0) {
      const title = "Unread Messages from Your Doctor";
      const body = `You have ${countFromDoctor} unread message(s) from your doctor. Open Safe Space to read them.`;

      await messaging.send({
        token: patient.fcmToken,
        notification: { title, body },
      });

      logger.info(`📬 Unread message digest sent to ${patientId}`);
    }
  }
});

// ✅ Notify patient when appointment is updated or canceled
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

  let title = "", body = "";

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

// ✅ Notify doctor when patient creates or reschedules appointment
exports.notifyDoctorOnAppointmentRequestOrReschedule = onDocumentCreated({
  document: "users/{userId}/appointments/{appointmentId}",
  region: "us-central1",
  platform: "gcfv1",
}, async (event) => {
  const appointment = event.data.data();
  const patientId = event.params.userId;
  const doctorId = appointment.doctorId;

  if (!doctorId) return;

  const doctorDoc = await db.collection("users").doc(doctorId).get();
  const patientDoc = await db.collection("users").doc(patientId).get();
  if (!doctorDoc.exists || !patientDoc.exists) return;

  const doctor = doctorDoc.data();
  const patient = patientDoc.data();
  const fcmToken = doctor.fcmToken;
  if (!fcmToken) return;

  let title = "";
  let body = "";

  if (appointment.status === "pending") {
    title = "New Appointment Request";
    body = `Patient ${patient.name} has requested an appointment.`;
  } else if (appointment.status === "rescheduled") {
    title = "Appointment Rescheduled";
    body = `Patient ${patient.name} has rescheduled their appointment.`;
  } else {
    return;
  }

  await messaging.send({
    token: fcmToken,
    notification: { title, body },
    data: {
      type: "appointment",
      patientId,
      appointmentId: event.params.appointmentId,
    },
  });

  logger.info(`📨 Doctor ${doctorId} notified about ${appointment.status} from patient ${patientId}`);
});

// ✅ Daily symptom reminder
exports.dailySymptomReminder = onSchedule({
  schedule: "0 19 * * *",
  timeZone: "Asia/Amman",
}, async () => {
  const patients = await db.collection("users").where("role", "==", "patient").get();
  const sendTasks = [];

  for (let doc of patients.docs) {
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
  }

  await Promise.all(sendTasks);
});

// ✅ Tomorrow’s confirmed appointment reminder
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

  for (let doc of snapshot.docs) {
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
