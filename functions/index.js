
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

const sgMail = require("@sendgrid/mail");
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

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

exports.sendUnreadNotificationDigest = onSchedule({
  secrets: ["SENDGRID_API_KEY"],
  schedule: "0 18 * * *",
  timeZone: "Asia/Amman",
  region: "us-central1"
}, async () => {
  const patients = await db.collection("users").where("role", "==", "patient").get();

  for (const patientDoc of patients.docs) {
    const patient = patientDoc.data();
    const patientId = patientDoc.id;

    if (!patient.fcmToken || !patient.doctorId || !patient.email) continue;

    const unreadNotificationsSnapshot = await db
      .collection("users")
      .doc(patientId)
      .collection("notifications")
      .where("read", "==", false)
      .where("digestSent", "==", false)
      .get();

    const unreadCount = unreadNotificationsSnapshot.size;

    if (unreadCount > 0) {
      const doctorDoc = await db.collection("users").doc(patient.doctorId).get();
      const doctor = doctorDoc.data();
      if (!doctor?.email) continue;

      const title = "You Have Unread Notifications";
      const body = `You have ${unreadCount} unread notification(s) from Safe Space.`;

      await messaging.sendToDevice(patient.fcmToken, {
        notification: { title, body },
        data: { type: "appointment_patient" }
      });

      const emailMsg = {
        to: patient.email,
        from: {
          email: "safe3space@gmail.com",
          name: `Safe Space - Dr. ${doctor.name || "Your Doctor"}`
        },
        replyTo: doctor.email,
        subject: "You Have Unread Notifications from Safe Space",
        text: `Hello ${patient.name || "there"},\n\nYou have ${unreadCount} unread notification(s). Please open the Safe Space app to review them.`,
        html: `<p>Hello ${patient.name || "there"},</p><p>You have <strong>${unreadCount}</strong> unread notification(s).</p><p><a href="https://yourapp.com">Open Safe Space</a> to review them.</p>`
      };

      try {
        await sgMail.send(emailMsg);
        logger.info(`📧 Email digest sent to ${patient.email}`);
      } catch (e) {
        logger.error(`❌ Failed to send email to ${patient.email}`, e);
      }

      const batch = db.batch();
      unreadNotificationsSnapshot.docs.forEach(doc => {
        batch.update(doc.ref, { digestSent: true });
      });
      await batch.commit();
      logger.info(`📬 Unread notification digest sent to ${patientId}`);
    }
  }
});

exports.sendAppointmentConfirmationEmail = onDocumentCreated({
  secrets: ["SENDGRID_API_KEY"],
  document: "users/{userId}/appointments/{appointmentId}",
  region: "us-central1"
}, async (event) => {
  const appointment = event.data.data();
  const userId = event.params.userId;

  if (!appointment || appointment.status !== "confirmed") return;

  const userDoc = await db.collection("users").doc(userId).get();
  const user = userDoc.data();
  if (!user?.email || !user?.doctorId) return;

  const doctorDoc = await db.collection("users").doc(user.doctorId).get();
  const doctor = doctorDoc.data();
  if (!doctor?.email) return;

  const apptTime = appointment.dateTime.toDate().toLocaleString("en-US", {
    timeZone: "Asia/Amman",
    weekday: "long", year: "numeric", month: "long", day: "numeric",
    hour: "2-digit", minute: "2-digit"
  });

  const title = "Appointment Confirmed";
  const body = `Your appointment is confirmed for ${apptTime}.`;

  await createNotification(userId, title, body);

  const emailMsg = {
    to: user.email,
    from: {
      email: "safe3space@gmail.com",
      name: `Safe Space - Dr. ${doctor.name || "Your Doctor"}`
    },
    replyTo: doctor.email,
    subject: "Your Appointment is Confirmed",
    text: `Hello ${user.name || "there"},\n\nYour appointment is confirmed for ${apptTime}.`,
    html: `<p>Hello ${user.name || "there"},</p><p>Your appointment is confirmed for <strong>${apptTime}</strong>.</p>`
  };

  try {
    await sgMail.send(emailMsg);
    logger.info(`📧 Appointment confirmation email sent to ${user.email}`);
  } catch (e) {
    logger.error(`❌ Failed to send confirmation email to ${user.email}`, e);
  }
});

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
        await messaging.sendToDevice(fcmToken, {
          notification: { title, body },
          data: { type: "appointment_patient" }
        });
      } catch (error) {
        logger.error("❌ FCM send error", error);
      }
    }
  }
});

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

  if (!patientData || !patientData.doctorId) return;

  const doctorId = patientData.doctorId;
  const doctorDoc = await db.collection("users").doc(doctorId).get();
  const doctorData = doctorDoc.data();

  if (!doctorData || !doctorData.fcmToken) return;

  const appointmentTime = after.dateTime.toDate?.() || new Date(after.dateTime);
  const formattedTime = appointmentTime.toLocaleString("en-US", {
    timeZone: "Asia/Amman",
    weekday: "long", year: "numeric", month: "short", day: "numeric",
    hour: "2-digit", minute: "2-digit",
  });

  const title = "Reschedule Request";
  const body = `${patientData.name || "A patient"} requested to reschedule their appointment on ${formattedTime}.`;

  try {
    await messaging.sendToDevice(doctorData.fcmToken, {
      notification: { title, body },
      data: { type: "appointment_doctor" }
    });
    await createNotification(doctorId, title, body);
    logger.info(`📬 Reschedule request sent to doctor ${doctorId}`);
  } catch (error) {
    logger.error("❌ Error sending reschedule notification to doctor", error);
  }
});

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

  const title = "⚠ Drastic Change in Patient's Vital Signs";
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

  await messaging.sendToDevice(doctor.fcmToken, {
    notification: { title, body },
    data: { type: "monitor" }
  });

  await createNotification(patient.doctorId, title, body);
  logger.info(`🚨 Drastic change notification sent to doctor ${patient.doctorId}`);
});
