const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ==========================================
// 🔧 工具方法：读取某个用户的 fcmToken
// ==========================================
async function getFcmToken(uid) {
  if (!uid) return null;
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) return null;
  const token = userDoc.data().fcmToken;
  return token || null;
}

// ==========================================
// 🔧 工具方法：发送一条 FCM 推送，token 为空则跳过
// ==========================================
async function sendNotification(token, payload) {
  if (!token) return;
  try {
    await messaging.send({
      token,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data || {},
    });
  } catch (e) {
    console.error("发送推送失败:", e);
  }
}

// ==========================================
// trigger 1：新的接单/谈价申请 -> 通知雇主
// ==========================================
exports.onNewApplication = functions.firestore
  .document("tasks/{taskId}/applications/{appId}")
  .onCreate(async (snap, context) => {
    try {
      const { taskId } = context.params;
      const application = snap.data();

      const taskDoc = await db.collection("tasks").doc(taskId).get();
      if (!taskDoc.exists) return;
      const taskData = taskDoc.data();

      const token = await getFcmToken(taskData.publisherId);
      if (!token) return;

      const isNegotiation = application.type === "negotiation";

      await sendNotification(token, {
        title: isNegotiation ? "⚖️ 收到新的出价谈判！" : "🎉 有人申请您的委托！",
        body: `${application.takerName} 出价 RM ${application.proposedAmount}`,
        data: {
          taskId,
          type: "new_application",
        },
      });
    } catch (e) {
      console.error("onNewApplication 出错:", e);
    }
  });

// ==========================================
// trigger 2：申请被录用 -> 通知接单人
// ==========================================
exports.onApplicationApproved = functions.firestore
  .document("tasks/{taskId}/applications/{appId}")
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();

      if (before.status === after.status) return;
      if (after.status !== "approved") return;

      const { taskId } = context.params;

      const token = await getFcmToken(after.takerId);
      if (!token) return;

      await sendNotification(token, {
        title: "✅ 恭喜！您被录用了！",
        body: "您的申请已通过，请前往任务聊天室查看详情",
        data: {
          taskId,
          type: "application_approved",
        },
      });
    } catch (e) {
      console.error("onApplicationApproved 出错:", e);
    }
  });

// ==========================================
// trigger 3：群聊新消息 -> 通知雇主 + 所有接单人（排除发送者）
// ==========================================
exports.onNewChatMessage = functions.firestore
  .document("tasks/{taskId}/messages/{msgId}")
  .onCreate(async (snap, context) => {
    try {
      const { taskId } = context.params;
      const message = snap.data();
      const senderId = message.senderId;

      const taskDoc = await db.collection("tasks").doc(taskId).get();
      if (!taskDoc.exists) return;
      const taskData = taskDoc.data();

      const acceptedUsers = taskData.acceptedUsers || [];
      const targetUids = new Set([taskData.publisherId, ...acceptedUsers]);
      targetUids.delete(senderId);
      targetUids.delete(undefined);
      targetUids.delete(null);

      const payload = {
        title: "💬 任务群聊有新消息",
        body: `${message.senderName}：${message.text}`,
        data: {
          taskId,
          type: "new_message",
        },
      };

      await Promise.all(
        Array.from(targetUids).map(async (uid) => {
          const token = await getFcmToken(uid);
          await sendNotification(token, payload);
        })
      );
    } catch (e) {
      console.error("onNewChatMessage 出错:", e);
    }
  });
