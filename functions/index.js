const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// ✅ Test Function
exports.helloWorld = onRequest({ region: "us-central1" }, (req, res) => {
  res.send("✅ Hello from Safe Space (Gen 2)");
});

// 🔔 Helper
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

// ✅ Chat Message Notification (no deduplication)
exports.notifyNewMessage = onDocumentCreated({
  document: "messages/{chatId}/chats/{messageId}",
  region: "us-central1",
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
    await messaging.send({ token: recipient.fcmToken, notification: { title, body } });
    await createNotification(recipientId, title, body);
    return;
  }

  if (
    sender.role === "patient" &&
    sender.doctorId === recipientId &&
    recipient.fcmToken
  ) {
    const title = "New Message from Your Patient";
    const body = `${sender.name || "Patient"}: ${message.text || "Sent a message"}`;
    await messaging.send({ token: recipient.fcmToken, notification: { title, body } });
    await createNotification(recipientId, title, body);
  }
});

// ✅ Appointment Update Notification
exports.notifyAppointmentChanged = onDocumentUpdated({
  document: "users/{userId}/appointments/{appointmentId}",
  region: "us-central1",
}, async (event) => {
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
      body = `Your appointment status changed to \"${after.status}\".`;
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

// ✅ Daily Unread Message Digest
exports.sendUnreadMessageDigest = onSchedule({
  schedule: "0 17 * * *",
  timeZone: "Asia/Amman",
  region: "us-central1"
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

// ✅ 24-Hour Appointment Reminder
exports.send24HourAppointmentReminder = onSchedule({
  schedule: "every 60 minutes",
  timeZone: "Asia/Amman",
  region: "us-central1"
}, async () => {
  const now = Timestamp.now();
  const millisNow = now.toMillis();
  const startWindow = Timestamp.fromMillis(millisNow + 24 * 60 * 60 * 1000 - 5 * 60 * 1000);
  const endWindow = Timestamp.fromMillis(millisNow + 24 * 60 * 60 * 1000 + 5 * 60 * 1000);

  const usersSnapshot = await db.collection("users").where("role", "==", "patient").get();

  for (const userDoc of usersSnapshot.docs) {
    const patientId = userDoc.id;
    const patientData = userDoc.data();
    if (!patientData.fcmToken) continue;

    const apptSnapshot = await db
      .collection("users")
      .doc(patientId)
      .collection("appointments")
      .where("status", "==", "confirmed")
      .where("dateTime", ">=", startWindow)
      .where("dateTime", "<=", endWindow)
      .get();

    for (const appt of apptSnapshot.docs) {
      const apptData = appt.data();

      const apptTime = apptData.dateTime.toDate().toLocaleString("en-US", {
        timeZone: "Asia/Amman",
        weekday: "long", year: "numeric", month: "long", day: "numeric",
        hour: "2-digit", minute: "2-digit"
      });

      const title = "Appointment Reminder";
      const body = `You have an appointment scheduled for ${apptTime}.`;

      await messaging.send({
        token: patientData.fcmToken,
        notification: { title, body }
      });

      await createNotification(patientId, title, body);
      logger.info(`⏰ 24-hour reminder sent to ${patientId} for appointment at ${apptTime}`);
    }
  }
});

// ✅ NEW: Drastic Recording Change Alert to Doctor
exports.notifyDoctorOfDrasticRecording = onDocumentCreated({
  document: "users/{patientId}/recordings/{recordingId}",
  region: "us-central1",
}, async (event) => {
  const data = event.data.data();
  const patientId = event.params.patientId;

  const { heartRate, temperature, spo2, timestamp } = data;

  const isHeartRateDrastic = heartRate < 50 || heartRate > 120;
  const isTempDrastic = temperature < 27 || temperature > 37.5;
  const isSpo2Drastic = spo2 < 90;

  if (!(isHeartRateDrastic || isTempDrastic || isSpo2Drastic)) {
    logger.info(`📉 No drastic change for patient ${patientId}`);
    return;
  }

  const patientDoc = await db.collection("users").doc(patientId).get();
  const patient = patientDoc.data();
  if (!patient || !patient.doctorId) return;

  const doctorDoc = await db.collection("users").doc(patient.doctorId).get();
  const doctor = doctorDoc.data();
  if (!doctor || !doctor.fcmToken) return;

  const recordedTime = (timestamp?.toDate?.() || new Date()).toLocaleString("en-US", {
    timeZone: "Asia/Amman",
    weekday: "short", year: "numeric", month: "short", day: "numeric",
    hour: "2-digit", minute: "2-digit"
  });

  const title = "⚠️ Drastic Change in Patient's Vital Signs";
  let body = `${patient.name || "A patient"} has abnormal readings at ${recordedTime}: `;
  if (isHeartRateDrastic) body += `Heart Rate: ${heartRate} bpm. `;
  if (isTempDrastic) body += `Temperature: ${temperature}°C. `;
  if (isSpo2Drastic) body += `SpO₂: ${spo2}%.`;

  const oneHourAgo = Timestamp.fromMillis(Date.now() - 60 * 60 * 1000);
  const recentNotif = await db.collection("users")
    .doc(patient.doctorId)
    .collection("notifications")
    .where("title", "==", title)
    .where("timestamp", ">=", oneHourAgo)
    .limit(1)
    .get();

  if (!recentNotif.empty) {
    logger.info(`⏱ Skipped duplicate alert to doctor ${patient.doctorId}`);
    return;
  }

  await messaging.send({
    token: doctor.fcmToken,
    notification: { title, body },
  });

  await createNotification(patient.doctorId, title, body);
  logger.info(`🚨 Drastic change notification sent to doctor ${patient.doctorId}`);
});
