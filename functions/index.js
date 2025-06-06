const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");
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

// ✅ Unread Digest
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
    if (unreadCount === 0) continue;

    const doctorDoc = await db.collection("users").doc(patient.doctorId).get();
    const doctor = doctorDoc.data();
    if (!doctor?.email) continue;

    const title = "You Have Unread Notifications";
    const body = `You have ${unreadCount} unread notification(s) from Safe Space.`;

    await messaging.send({
      token: patient.fcmToken,
      data: { title, body, type: "appointment_patient" }
    });

    const emailMsg = {
      to: patient.email,
      from: {
        email: "safe3space@gmail.com",
        name: `Safe Space - Dr. ${doctor.name || "Your Doctor"}`
      },
      replyTo: doctor.email,
      subject: "You Have Unread Notifications from Safe Space",
      text: `Hello ${patient.name || "there"},

You have ${unreadCount} unread notification(s). Please open the Safe Space app to review them.`,
      html: `<p>Hello ${patient.name || "there"},</p><p>You have <strong>${unreadCount}</strong> unread notification(s).</p><p>Open Safe Space to review them.</p>`
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
});

// ✅ Daily Symptom Reminder
exports.sendDailySymptomReminder = onSchedule({
  schedule: "0 16 * * *",
  timeZone: "Asia/Amman",
  region: "us-central1"
}, async () => {
  const snapshot = await db.collection("users").where("role", "==", "patient").get();

  for (const doc of snapshot.docs) {
    const patient = doc.data();
    const fcmToken = patient.fcmToken;
    const userId = doc.id;

    if (!fcmToken) continue;

    const title = "Daily Symptom Check";
    const body = "Don't forget to check in and log your symptoms in Safe Space today.";

    await messaging.send({
      token: fcmToken,
      data: { title, body, type: "daily_reminder" }
    });

    await createNotification(userId, title, body);
  }

  logger.info("✅ Daily symptom reminders sent to all patients.");
});

// ✅ Appointment Confirmed
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

  if (user.fcmToken) {
    await messaging.send({
      token: user.fcmToken,
      data: { title, body, type: "appointment_patient" }
    });
  }

  const emailMsg = {
    to: user.email,
    from: {
      email: "safe3space@gmail.com",
      name: `Safe Space - Dr. ${doctor.name || "Your Doctor"}`
    },
    replyTo: doctor.email,
    subject: "Your Appointment is Confirmed",
    text: `Hello ${user.name || "there"},

Your appointment is confirmed for ${apptTime}.`,
    html: `<p>Hello ${user.name || "there"},</p><p>Your appointment is confirmed for <strong>${apptTime}</strong>.</p>`
  };

  try {
    await sgMail.send(emailMsg);
    logger.info(`📧 Appointment confirmation email sent to ${user.email}`);
  } catch (e) {
    logger.error(`❌ Failed to send confirmation email to ${user.email}`, e);
  }
});

// ✅ Patient Credentials on Creation
exports.sendPatientCredentialsOnCreation = onDocumentCreated({
  secrets: ["SENDGRID_API_KEY"],
  document: "users/{userId}",
  region: "us-central1"
}, async (event) => {
  const user = event.data.data();
  const userId = event.params.userId;

  logger.info(`🟡 Triggered sendPatientCredentialsOnCreation for user: ${userId}`);

  if (!user || user.role !== 'patient' || !user.generatedPassword || !user.email) {
    logger.warn(`⚠️ Skipping credential email — Missing fields for user: ${userId}`);
    return;
  }

  const emailMsg = {
    to: user.email,
    from: {
      email: "safe3space@gmail.com",
      name: "Safe Space Team"
    },
    subject: "Your Safe Space Login Credentials",
    text: `Hello ${user.name || "there"},

You have been registered to the Safe Space app.

Login Email: ${user.email}
Password: ${user.generatedPassword}

Please log in and change your password immediately for your security.`,
    html: `
      <p>Hello ${user.name || "there"},</p>
      <p>You have been registered to the <strong>Safe Space</strong> app.</p>
      <p><strong>Login Email:</strong> ${user.email}<br/>
         <strong>Password:</strong> ${user.generatedPassword}</p>
      <p>Please log in and <strong>change your password immediately</strong> for security.</p>
      <p>Regards,<br/>Safe Space Team</p>
    `
  };

  try {
    await sgMail.send(emailMsg);
    logger.info(`📧 Credentials email sent to ${user.email}`);
  } catch (e) {
    logger.error(`❌ Failed to send credentials email to ${user.email}`, e);
  }

  await db.collection("users").doc(userId).update({
    generatedPassword: FieldValue.delete()
  });
});
// ✅ Drastic Recording Alert
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

  await messaging.send({
    token:doctor.fcmToken,
    data: { title, body, type: "monitor" }
  });

  await createNotification(patient.doctorId, title, body);
  logger.info(`🚨 Drastic change notification sent to doctor ${patient.doctorId}`);
});

// ✅ Appointment Updated
exports.notifyAppointmentChanged = onDocumentUpdated({
  document: "users/{userId}/appointments/{appointmentId}",
  region: "us-central1",
}, async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const userId = event.params.userId;

  logger.info(`📅 Appointment update triggered for user: ${userId}`);
  logger.info(`📋 After data: ${JSON.stringify(after)}`);

  if (after.status === "rescheduled") return;

  const userDoc = await db.collection("users").doc(userId).get();
  const patient = userDoc.data();
  const fcmToken = patient?.fcmToken;

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
    // Notify the patient
    await createNotification(userId, title, body);
    logger.info(`🔔 Notification created for patient: ${userId}`);

    if (fcmToken) {
      await messaging.send({
        token: fcmToken,
        data: { title, body, type: "appointment_patient" }
      });
      logger.info(`📨 FCM sent to patient: ${userId}`);
    }

    // 🔍 DEBUG: Check doctor notification condition
    logger.info(`🧪 DEBUG: status=${after.status}, doctorId=${after.doctorId}`);

    // Notify the doctor only if status is "pending"
    if (after.status?.toLowerCase() === "pending" && after.doctorId) {
      logger.info(`📨 Sending FCM to doctor: ${after.doctorId}`);

      const doctorDoc = await db.collection("users").doc(after.doctorId).get();
      const doctor = doctorDoc.data();
      const doctorToken = doctor?.fcmToken;

      logger.info(`🎯 Doctor FCM: ${doctorToken}`);

      if (doctorToken) {
        const doctorTitle = `New Appointment Request`;
        const doctorBody = `You have a new pending appointment from ${patient?.name || "a patient"} for ${formattedDate}.`;

        await messaging.send({
          token: doctorToken,
          data: { title: doctorTitle, body: doctorBody, type: "appointment_doctor" }
        });

        await createNotification(after.doctorId, doctorTitle, doctorBody);
        logger.info(`✅ FCM + notification sent to doctor: ${after.doctorId}`);
      } else {
        logger.warn(`⚠️ Doctor has no FCM token: ${after.doctorId}`);
      }
    } else {
      logger.info(`ℹ️ Doctor not notified (status: ${after.status}, doctorId: ${after.doctorId})`);
    }
  } else {
    logger.info("ℹ️ No meaningful changes in appointment. No notifications sent.");
  }
});
exports.notifyAppointmentCreated = onDocumentCreated({
  document: "users/{userId}/appointments/{appointmentId}",
  region: "us-central1"
}, async (event) => {
  const data = event.data.data();
  const userId = event.params.userId;

  logger.info(`📅 Appointment created for user: ${userId}`);
  logger.info(`📋 Created data: ${JSON.stringify(data)}`);

  if (data.status?.toLowerCase() !== "pending" || !data.doctorId) {
    logger.info(`ℹ️ Not notifying doctor: status=${data.status}, doctorId=${data.doctorId}`);
    return;
  }

  const userDoc = await db.collection("users").doc(userId).get();
  const patient = userDoc.data();
  const doctorDoc = await db.collection("users").doc(data.doctorId).get();
  const doctor = doctorDoc.data();
  const doctorToken = doctor?.fcmToken;

  const formattedDate = data.dateTime.toDate().toLocaleString("en-US", {
    timeZone: "Asia/Amman",
    weekday: "long", year: "numeric", month: "long", day: "numeric",
    hour: "2-digit", minute: "2-digit"
  });

  const title = `New Appointment Request`;
  const body = `You have a new pending appointment from ${patient?.name || "a patient"} for ${formattedDate}.`;

  if (doctorToken) {
    await messaging.send({
      token: doctorToken,
      data: { title, body, type: "appointment_doctor" }
    });
    await createNotification(data.doctorId, title, body);
    logger.info(`✅ Doctor notified of new appointment: ${data.doctorId}`);
  } else {
    logger.warn(`⚠️ Doctor has no FCM token: ${data.doctorId}`);
  }
});

