const functions = require("firebase-functions");
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");

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

// ==========================================
// 🤖 AI 助手：润色任务描述（Google Gemini）
// ==========================================
exports.improveTaskDescription = onCall(async (request) => {
  const roughDescription = request.data.description;
  if (!roughDescription || roughDescription.trim().length < 5) {
    throw new Error("描述太短了！");
  }

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

  const prompt = `你是一个帮助马来西亚用户写任务委托描述的助手。
用户的粗略想法是："${roughDescription}"

请改写成清晰、友善、吸引接单人的任务描述。要求：
- 说明任务内容和地点（如果有）
- 说明完成标准
- 语气轻松友善
- 100字以内
- 直接给出描述，不加任何前缀说明`;

  const result = await model.generateContent(prompt);
  const text = result.response.text();
  return { description: text };
});

// ==========================================
// 🤖 AI 助手：建议任务定价（Google Gemini）
// ==========================================
exports.suggestTaskPrice = onCall(async (request) => {
  const { description, location } = request.data;

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

  const prompt = `你是马来西亚本地任务平台的定价顾问。
任务描述：${description}
地点：${location}

请根据马来西亚吉打州的市场行情，建议合理的任务报酬范围。
只返回 JSON 格式，不要其他文字：
{"min": 数字, "max": 数字, "suggestion": "一句话说明定价依据"}`;

  const result = await model.generateContent(prompt);
  const text = result.response.text().trim();
  const clean = text.replace(/```json|```/g, "").trim();
  return JSON.parse(clean);
});

// ==========================================
// 🔥 trigger 4：新发布的急单 -> 推送给所有已通过 KYC 的用户
// ==========================================
exports.onUrgentTask = functions.firestore
  .document("tasks/{taskId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data.isUrgent) return;

    const taskId = context.params.taskId;

    // 查询所有已通过 KYC 的用户 FCM token
    const usersSnap = await admin.firestore()
      .collection("users")
      .where("kyc_status", "==", "approved")
      .get();

    const tokens = usersSnap.docs
      .map((doc) => doc.data().fcmToken)
      .filter((token) => token && token !== data.publisherId);

    if (tokens.length === 0) return;

    // 批量发送，每次最多 500 个
    const chunks = [];
    for (let i = 0; i < tokens.length; i += 500) {
      chunks.push(tokens.slice(i, i + 500));
    }

    for (const chunk of chunks) {
      await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: {
          title: "🔥 附近有急单！",
          body: `${data.description?.substring(0, 40)}... RM ${data.amount}`,
        },
        data: { taskId, type: "urgent_task" },
      });
    }
  });
