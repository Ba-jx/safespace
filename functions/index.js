const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
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
      data: {
        title,
        body,
        type: "appointment_patient"
      }
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
  schedule: "0 16 * * *", // 4:00 PM Asia/Amman
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

// ✅ Appointment Updated
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
      await messaging.send({
        token: fcmToken,
        data: { title, body, type: "appointment_patient" }
      });
    }
  }
});

// ✅ Appointment Deleted
exports.notifyAppointmentDeleted = onDocumentDeleted({
  document: "users/{userId}/appointments/{appointmentId}",
  region: "us-central1",
}, async (event) => {
  const userId = event.params.userId;

  const userDoc = await db.collection("users").doc(userId).get();
  const user = userDoc.data();
  if (!user?.fcmToken) return;

  const title = "Appointment Deleted";
  const body = "Your appointment has been removed from the system.";

  await createNotification(userId, title, body);
  await messaging.send({
    token: user.fcmToken,
    data: { title, body, type: "appointment_patient" }
  });
});

// ✅ Reschedule Request to Doctor
exports.notifyDoctorOnRescheduleRequest = onDocumentUpdated({
  document: "users/{patientId}/appointments/{appointmentId}",
  region: "us-central1",
}, async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  const isRescheduled = after.status === "rescheduled";
  const isChanged = before.dateTime.toMillis() !== after.dateTime.toMillis() || before.note !== after.note;

  if (!isRescheduled || !isChanged) return;

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
  const body = `${patientData.name || "A patient"} requested to reschedule their appointment to ${formattedTime}.`;

  await messaging.send({
    token: doctorData.fcmToken,
    data: { title, body, type: "appointment_doctor" }
  });

  await createNotification(doctorId, title, body);
});
// ✅ Send Patient Credentials on Creation
exports.sendPatientCredentialsOnCreation = onDocumentCreated({
  secrets: ["SENDGRID_API_KEY"],
  document: "users/{userId}",
  region: "us-central1"
}, async (event) => {
  const user = event.data.data();
  const userId = event.params.userId;

  // Send only for patients with a generatedPassword field
  if (!user || user.role !== 'patient' || !user.generatedPassword || !user.email) return;

  const emailMsg = {
    to: user.email,
    from: {
      email: "safe3space@gmail.com",
      name: `Safe Space Team`
    },
    subject: "Your Safe Space Login Credentials",
    text: `Hello ${user.name || "there"},\n\nYou have been registered to the Safe Space app.\n\nLogin Email: ${user.email}\nPassword: ${user.generatedPassword}\n\nPlease log in and change your password immediately for your security.`,
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
    console.log(`📧 Credentials email sent to ${user.email}`);
  } catch (e) {
    console.error(`❌ Failed to send credentials email to ${user.email}`, e);
  }

  // Optional: delete the plain password after sending
  await db.collection("users").doc(userId).update({
    generatedPassword: admin.firestore.FieldValue.delete()
  });
});

