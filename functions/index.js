const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Função que dispara sempre que um documento é criado
 * na coleção 'notifications'.
 */
exports.sendPushNotification = functions.firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();

    const receiverId = data.receiverId;
    const title = data.title || "Nova Notificação";
    const message = data.message || "Você recebeu uma nova notificação!";
    const type = data.type || "default";

    console.log("📨 Notificação criada para:", receiverId);

    // Buscar o deviceToken armazenado do usuário
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(receiverId)
      .get();

    if (!userDoc.exists) {
      console.log("❌ Usuário não encontrado, cancelando envio.");
      return;
    }

    const token = userDoc.get("deviceToken");

    if (!token) {
      console.log("⚠ Usuário sem deviceToken, não é possível enviar.");
      return;
    }

    // Monta payload da notificação
    const payload = {
      notification: {
        title: title,
        body: message,
        sound: "default",
      },
      data: {
        type: type,
        senderId: data.senderId || "",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    try {
      await admin.messaging().sendToDevice(token, payload, {
        priority: "high",
        timeToLive: 60 * 60 * 24, // 24 horas
      });

      console.log("✔ Notificação enviada com sucesso!");
    } catch (error) {
      console.error("❌ Erro ao enviar push:", error);
    }
  });
