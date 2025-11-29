const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
admin.initializeApp();

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "hiroyamasaki0939@gmail.com",
    pass: "chps gdzm xcyc iprl",
  },
});

// Gửi OTP đăng nhập
exports.sendOtpMail = functions.https.onRequest((req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  let email, otp;
  try {
    ({ email, otp } = req.body || {});
  } catch (e) {
    res.set("Access-Control-Allow-Origin", "*");
    return res.status(400).send("Invalid JSON");
  }
  if (!email || !otp) {
    res.set("Access-Control-Allow-Origin", "*");
    return res.status(400).send("Missing email or otp");
  }
  transporter.sendMail({
    from: "\"Gmail Clone\" <hiroyamasaki0939@gmail.com>",
    to: email,
    subject: "Mã xác thực đăng nhập Gmail Clone",
    text: `Mã OTP của bạn là: ${otp}`,
  }).then(() => {
    res.set("Access-Control-Allow-Origin", "*");
    res.status(200).send("Sent");
  }).catch((e) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.status(500).send("Error: " + e.toString());
  });
});

// Gửi email xác thực với link
exports.sendVerifyEmail = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(204).send("");

  let email, name, userId, verify_code;
  try {
    ({ email, name, userId, verify_code } = req.body || {});
  } catch (e) {
    return res.status(400).send("Invalid JSON");
  }
  if (!email || !userId || !verify_code) {
    return res.status(400).send("Missing email, userId or verify_code");
  }

  // Link xác thực (triển khai trên region us-central1)
  const verifyLink = `https://us-central1-flutter-email-459809.cloudfunctions.net/verifyEmail?userId=${userId}&code=${verify_code}`;

  const html = `<p>Xin chào ${name || ""},</p>
    <p>Nhấn vào link sau để xác thực email cho tài khoản Gmail Clone:</p>
    <p><a href="${verifyLink}">Xác thực email</a></p>
    <p>Nếu không phải bạn đăng ký, hãy bỏ qua email này.</p>`;

  try {
    await transporter.sendMail({
      from: "\"Gmail Clone\" <hiroyamasaki0939@gmail.com>",
      to: email,
      subject: "Xác thực email Gmail Clone",
      html,
    });
    res.status(200).send("Sent");
  } catch (e) {
    res.status(500).send("Error: " + e.toString());
  }
});

// Xử lý xác thực khi nhấn link
exports.verifyEmail = functions.https.onRequest(async (req, res) => {
  const { userId, code } = req.query;
  if (!userId || !code) {
    return res.status(400).send("Thiếu thông tin xác thực");
  }
  try {
    const userRef = admin.firestore().collection("users").doc(userId);
    const userDoc = await userRef.get();
    if (!userDoc.exists) return res.status(404).send("Không tìm thấy tài khoản");
    const data = userDoc.data();
    if (data.email_verified === true) {
      return res.send("Email đã được xác thực trước đó!");
    }
    if (data.verify_code === code) {
      await userRef.update({ email_verified: true });
      return res.send("Xác thực email thành công! Bạn có thể quay lại ứng dụng để đăng nhập.");
    } else {
      return res.status(400).send("Mã xác thực không đúng!");
    }
  } catch (e) {
    return res.status(500).send("Lỗi xác thực: " + e.toString());
  }
});
exports.sendResetPasswordMail = functions.https.onRequest((req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") {
        return res.status(204).send("");
    }
    let email, name, reset_code;
    try {
        ({ email, name, reset_code } = req.body || {});
    } catch (e) {
        res.set("Access-Control-Allow-Origin", "*");
        return res.status(400).send("Invalid JSON");
    }
    if (!email || !reset_code) {
        res.set("Access-Control-Allow-Origin", "*");
        return res.status(400).send("Missing email or reset_code");
    }
    transporter.sendMail({
        from: "\"Gmail Clone\" <hiroyamasaki0939@gmail.com>",
        to: email,
        subject: "Yêu cầu đặt lại mật khẩu Gmail Clone",
        text: `Xin chào ${name || ""},\n\nMã đặt lại mật khẩu của bạn là: ${reset_code}\nVui lòng nhập mã này vào ứng dụng để đặt lại mật khẩu mới.\n\nNếu bạn không yêu cầu, hãy bỏ qua email này.`,
    }).then(() => {
        res.set("Access-Control-Allow-Origin", "*");
        res.status(200).send("Sent");
    }).catch((e) => {
        res.set("Access-Control-Allow-Origin", "*");
        res.status(500).send("Error: " + e.toString());
    });
});

exports.sendMailNotification = onDocumentCreated("mails_users/{mailsUsersId}", async (event) => {
  const snap = event.data;
  if (!snap) return null;
  const mailsUsers = snap.data();
  if (!mailsUsers) return null;

  // Lấy mailId và receiverId
  const mailId = mailsUsers.mailId;
  const receiverId = mailsUsers.receiverId;
  if (!mailId || !receiverId) return null;

  // Lấy thông tin mail (subject, senderName, createdAt)
  const mailSnap = await admin.firestore().collection("mails").doc(mailId).get();
  if (!mailSnap.exists) return null;
  const mail = mailSnap.data();

  // Nếu chưa đến thời gian createdAt thì không gửi thông báo
  if (mail.createdAt) {
    const createdAt = new Date(mail.createdAt);
    const now = new Date();
    if (createdAt > now) {
      console.log("Mail chưa đến thời gian gửi, không gửi FCM:", mailId);
      return null;
    }
  }

  // Lấy FCM token và cài đặt notification của user nhận
  const userSnap = await admin.firestore().collection("users").doc(receiverId).get();
  if (!userSnap.exists) return null;
  const user = userSnap.data();
  // Nếu user tắt notification thì không gửi thông báo
  if (user.notification === false) {
    console.log("User đã tắt notification, không gửi FCM:", receiverId);
    return null;
  }
  // Ưu tiên lấy fcmTokenAndroid nếu có, fallback sang fcmToken
  const fcmToken = user.fcmTokenAndroid || user.fcmToken;
  if (!fcmToken) {
    console.log("Không tìm thấy fcmToken cho user:", receiverId);
    return null;
  }

  // Soạn payload thông báo
  const payload = {
    notification: {
      title: "Bạn có email mới!",
      body: `${mail.senderName ? `[${mail.senderName}] ` : ""}${mail.subject || "Có thư mới trong hộp thư đến"}`,
      sound: "default"
    },
    data: {
      mailId: mailId,
      senderName: mail.senderName || "",
      createdAt: mail.createdAt ? mail.createdAt.toString() : "",
      subject: mail.subject || "",
      receiverId: receiverId
    }
  };

  // Gửi FCM và log kết quả
  try {
    const response = await admin.messaging().sendToDevice(fcmToken, payload);
    console.log("Đã gửi FCM:", JSON.stringify(response));
  } catch (e) {
    console.error("Lỗi gửi FCM:", e);
  }
  return null;
});
// ...existing code...

exports.sendMailNotificationAndroid = onDocumentCreated("mails_users/{mailsUsersId}", async (event) => {
  const snap = event.data;
  if (!snap) return null;
  const mailsUsers = snap.data();
  if (!mailsUsers) return null;

  // Lấy mailId và receiverId
  const mailId = mailsUsers.mailId;
  const receiverId = mailsUsers.receiverId;
  if (!mailId || !receiverId) return null;

  // Lấy thông tin mail (subject, senderName, createdAt)
  const mailSnap = await admin.firestore().collection("mails").doc(mailId).get();
  if (!mailSnap.exists) return null;
  const mail = mailSnap.data();

  // Nếu chưa đến thời gian createdAt thì không gửi thông báo
  if (mail.createdAt) {
    const createdAt = new Date(mail.createdAt);
    const now = new Date();
    if (createdAt > now) {
      console.log("Mail chưa đến thời gian gửi, chưa gửi thông báo Android.");
      return null;
    }
  }

  // Lấy FCM token Android và cài đặt notification của user nhận
  const userSnap = await admin.firestore().collection("users").doc(receiverId).get();
  if (!userSnap.exists) return null;
  const user = userSnap.data();
  // Nếu user tắt notification thì không gửi thông báo
  if (user.notification === false) {
    console.log("User đã tắt notification, không gửi FCM Android:", receiverId);
    return null;
  }
  const fcmTokenAndroid = user.fcmTokenAndroid;
  if (!fcmTokenAndroid) {
    console.log("Không tìm thấy fcmTokenAndroid cho user:", receiverId);
    return null;
  }

  // Soạn mess thông báo cho Android
  const message = {
    notification: {
      title: "Bạn có email mới!",
      body: `${mail.senderName ? `[${mail.senderName}] ` : ""}${mail.subject || "Có thư mới trong hộp thư đến"}${mail.createdAt ? `\nLúc: ${new Date(mail.createdAt).toLocaleString("vi-VN", { hour: "2-digit", minute: "2-digit", day: "2-digit", month: "2-digit", year: "numeric" })}` : ""}`
      // KHÔNG có sound ở đây!
    },
    data: {
      mailId: mailId,
      senderName: mail.senderName || "",
      createdAt: mail.createdAt ? mail.createdAt.toString() : "",
      subject: mail.subject || "",
      receiverId: receiverId // Thêm dòng này
    },
    token: fcmTokenAndroid
  };
  
  try {
    const response = await admin.messaging().send(message);
    console.log("Đã gửi FCM Android:", JSON.stringify(response));
  } catch (e) {
    console.error("Lỗi gửi FCM Android:", e);
  }
  return null;
});

const { onSchedule } = require("firebase-functions/v2/scheduler");
exports.scheduledSendMailNotificationAndroid = onSchedule("every 1 minutes", async () => {
  const now = new Date(Date.now() + 7 * 60 * 60 * 1000);
  const nowStr = now.toISOString().slice(0, 19); // "YYYY-MM-DDTHH:mm:ss"
  const mailsSnap = await admin.firestore().collection("mails")
    .where("createdAt", "<=", nowStr)
    .get();
  
  console.log("Tìm thấy", mailsSnap.docs.length, "mail cần kiểm tra");
  for (const mailDoc of mailsSnap.docs) {
    const mail = mailDoc.data();
    // Kiểm tra đã gửi thông báo chưa (ví dụ: mail.notifiedAndroid !== true)
    if (mail.notifiedAndroid) {
      console.log("Mail", mailDoc.id, "đã gửi thông báo, bỏ qua");
      continue;
    }

    // Lấy danh sách receiver từ mails_users
    const mailsUsersSnap = await admin.firestore().collection("mails_users")
      .where("mailId", "==", mailDoc.id)
      .get();

    for (const muDoc of mailsUsersSnap.docs) {
      const mu = muDoc.data();
      const receiverId = mu.receiverId;
      const userSnap = await admin.firestore().collection("users").doc(receiverId).get();
      if (!userSnap.exists) continue;
      const user = userSnap.data();
      // Nếu user tắt notification thì không gửi thông báo
      if (user.notification === false) {
        console.log("User đã tắt notification, không gửi FCM Android (schedule):", receiverId);
        continue;
      }
      const fcmTokenAndroid = user.fcmTokenAndroid;
      if (!fcmTokenAndroid) continue;

      const message = {
        notification: {
          title: "Bạn có email mới!",
          body: `${mail.senderName ? `[${mail.senderName}] ` : ""}${mail.subject || "Có thư mới trong hộp thư đến"}${mail.createdAt ? `\nLúc: ${new Date(mail.createdAt).toLocaleString("vi-VN")}` : ""}`
        },
        data: {
          mailId: mailDoc.id,
          senderName: mail.senderName || "",
          createdAt: mail.createdAt ? mail.createdAt.toString() : "",
          subject: mail.subject || "",
          receiverId: receiverId // Thêm dòng này
        },
        token: fcmTokenAndroid
      };

      try {
        await admin.messaging().send(message);
        console.log("Đã gửi FCM Android:", receiverId);
      } catch (e) {
        console.error("Lỗi gửi FCM Android:", e);
      }
    }
    // Đánh dấu đã gửi thông báo
    await mailDoc.ref.update({ notifiedAndroid: true });
  }
  return null;
});
// Gửi thông báo FCM cho Web khi có mail mới
exports.sendMailNotificationWeb = onDocumentCreated("mails_users/{mailsUsersId}", async (event) => {
  const snap = event.data;
  if (!snap) return null;
  const mailsUsers = snap.data();
  if (!mailsUsers) return null;

  const mailId = mailsUsers.mailId;
  const receiverId = mailsUsers.receiverId;
  if (!mailId || !receiverId) return null;

  const mailSnap = await admin.firestore().collection("mails").doc(mailId).get();
  if (!mailSnap.exists) return null;
  const mail = mailSnap.data();

  if (mail.createdAt) {
    const createdAt = new Date(mail.createdAt);
    const now = new Date();
    if (createdAt > now) {
      console.log("Mail chưa đến thời gian gửi, chưa gửi thông báo Web.");
      return null;
    }
  }

  const userSnap = await admin.firestore().collection("users").doc(receiverId).get();
  if (!userSnap.exists) return null;
  const user = userSnap.data();
  if (user.notification === false) {
    console.log("User đã tắt notification, không gửi FCM Web:", receiverId);
    return null;
  }
  const fcmTokenWeb = user.fcmTokenWeb;
  if (!fcmTokenWeb) {
    console.log("Không tìm thấy fcmTokenWeb cho user:", receiverId);
    return null;
  }

  const message = {
    notification: {
      title: "Bạn có email mới!",
      body: `${mail.senderName ? `[${mail.senderName}] ` : ""}${mail.subject || "Có thư mới trong hộp thư đến"}${mail.createdAt ? `\nLúc: ${new Date(mail.createdAt).toLocaleString("vi-VN", { hour: "2-digit", minute: "2-digit", day: "2-digit", month: "2-digit", year: "numeric" })}` : ""}`,
      icon: "/mail_icon.png" // Nếu bạn có icon riêng cho web
    },
    data: {
      mailId: mailId,
      senderName: mail.senderName || "",
      createdAt: mail.createdAt ? mail.createdAt.toString() : "",
      subject: mail.subject || "",
      receiverId: receiverId
    },
    token: fcmTokenWeb
  };

  try {
    const response = await admin.messaging().send(message);
    console.log("Đã gửi FCM Web:", JSON.stringify(response));
  } catch (e) {
    console.error("Lỗi gửi FCM Web:", e);
  }
  return null;
});

// const { onSchedule } = require("firebase-functions/v2/scheduler");
// Gửi thông báo FCM Web theo lịch (phòng trường hợp gửi chậm hoặc user offline)
exports.scheduledSendMailNotificationWeb = onSchedule("every 1 minutes", async () => {
  const now = new Date(Date.now() + 7 * 60 * 60 * 1000);
  const nowStr = now.toISOString().slice(0, 19);
  const mailsSnap = await admin.firestore().collection("mails")
    .where("createdAt", "<=", nowStr)
    .get();

  console.log("Tìm thấy", mailsSnap.docs.length, "mail cần kiểm tra (Web)");
  for (const mailDoc of mailsSnap.docs) {
    const mail = mailDoc.data();
    if (mail.notifiedWeb) {
      console.log("Mail", mailDoc.id, "đã gửi thông báo Web, bỏ qua");
      continue;
    }

    const mailsUsersSnap = await admin.firestore().collection("mails_users")
      .where("mailId", "==", mailDoc.id)
      .get();

    for (const muDoc of mailsUsersSnap.docs) {
      const mu = muDoc.data();
      const receiverId = mu.receiverId;
      const userSnap = await admin.firestore().collection("users").doc(receiverId).get();
      if (!userSnap.exists) continue;
      const user = userSnap.data();
      if (user.notification === false) {
        console.log("User đã tắt notification, không gửi FCM Web (schedule):", receiverId);
        continue;
      }
      const fcmTokenWeb = user.fcmTokenWeb;
      if (!fcmTokenWeb) continue;

      const message = {
        notification: {
          title: "Bạn có email mới!",
          body: `${mail.senderName ? `[${mail.senderName}] ` : ""}${mail.subject || "Có thư mới trong hộp thư đến"}${mail.createdAt ? `\nLúc: ${new Date(mail.createdAt).toLocaleString("vi-VN")}` : ""}`,
          icon: "/mail_icon.png"
        },
        data: {
          mailId: mailDoc.id,
          senderName: mail.senderName || "",
          createdAt: mail.createdAt ? mail.createdAt.toString() : "",
          subject: mail.subject || "",
          receiverId: receiverId
        },
        token: fcmTokenWeb
      };

      try {
        await admin.messaging().send(message);
        console.log("Đã gửi FCM Web:", receiverId);
      } catch (e) {
        console.error("Lỗi gửi FCM Web:", e);
      }
    }
    await mailDoc.ref.update({ notifiedWeb: true });
  }
  return null;
});
// ...existing code...