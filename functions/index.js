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

// ✅ Modified: Appointment Update Notification (skip all if reschedule_requested)
exports.notifyAppointmentChanged = onDocumentUpdated({
  document: "users/{userId}/appointments/{appointmentId}",
  region: "us-central1",
}, async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const userId = event.params.userId;

  if (after.status === "rescheduled") return;

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

// ✅ Notify Doctor When Patient Requests Rescheduling
exports.notifyDoctorOnRescheduleRequest = onDocumentUpdated({
  document: "users/{patientId}/appointments/{appointmentId}",
  region: "us-central1",
}, async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status || after.status !== "rescheduled") return;

  const patientId = event.params.patientId;
  const patientDoc = await db.collection("users").doc(patientId).get();
  const patientData = patientDoc.data();

  if (!patientData || !patientData.doctorId) {
    logger.warn(`❌ Patient ${patientId} has no doctorId`);
    return;
  }

  const doctorId = patientData.doctorId;
  const doctorDoc = await db.collection("users").doc(doctorId).get();
  const doctorData = doctorDoc.data();

  console.log("🔍 doctorId:", doctorId);
  console.log("🔍 doctor fcmToken:", doctorData?.fcmToken);

  if (!doctorData || !doctorData.fcmToken) {
    logger.warn(`❌ Doctor ${doctorId} not found or missing fcmToken`);
    return;
  }

  const appointmentTime = after.dateTime.toDate?.() || new Date(after.dateTime);
  const formattedTime = appointmentTime.toLocaleString("en-US", {
    timeZone: "Asia/Amman",
    weekday: "long", year: "numeric", month: "short", day: "numeric",
    hour: "2-digit", minute: "2-digit",
  });

  const title = "Reschedule Request";
  const body = `${patientData.name || "A patient"} requested to reschedule their appointment on ${formattedTime}.`;

  try {
    await messaging.send({
      token: doctorData.fcmToken,
      notification: { title, body },
    });

    await createNotification(doctorId, title, body);
    logger.info(`📬 Reschedule request sent to doctor ${doctorId}`);
  } catch (error) {
    logger.error("❌ Error sending reschedule notification to doctor", error);
  }
});

// ✅ Notify Doctor of Drastic Readings
exports.notifyDoctorOfDrasticRecording = onDocumentCreated({
  document: "users/{patientId}/readings/{readingId}",
  region: "us-central1",
}, async (event) => {
  logger.info(`📅 New reading created for patient ${event.params.patientId}`);

  const data = event.data.data();
  const patientId = event.params.patientId;

  const { heartRate, temperature, spo2, timestamp } = data;

  const isHeartRateDrastic = heartRate < 50 || heartRate > 120;
  const isTempDrastic = temperature < 27 || temperature > 37.5;
  const isSpo2Drastic = spo2 < 90;

  if (!(isHeartRateDrastic || isTempDrastic || isSpo2Drastic)) {
    logger.info(`🔽 No drastic change for patient ${patientId}`);
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

  const tenSecondsAgo = Timestamp.fromMillis(Date.now() - 10 * 1000);
  const recentNotif = await db.collection("users")
    .doc(patient.doctorId)
    .collection("notifications")
    .where("title", "==", title)
    .where("timestamp", ">=", tenSecondsAgo)
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
