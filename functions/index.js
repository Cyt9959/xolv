const functions = require("firebase-functions");
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { RtcTokenBuilder, RtcRole } = require("agora-token");

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
// 📞 trigger：新通话邀请 -> 推送给接收方，30秒无应答自动 timeout
// ==========================================
exports.onCallCreated = functions.firestore
  .document("calls/{callId}")
  .onCreate(async (snap, context) => {
    try {
      const data = snap.data();
      if (data.status !== "ringing") return;

      // 获取接收方的 FCM token
      const receiverDoc = await db.collection("users").doc(data.receiverId).get();
      const token = receiverDoc.data()?.fcmToken;

      if (token) {
        const callType = data.type === "video" ? "视频" : "语音";

        await messaging.send({
          token,
          notification: {
            title: `📞 ${data.callerName} 来${callType}电话了`,
            body: "点击接听",
          },
          data: {
            type: "incoming_call",
            callId: context.params.callId,
            callerId: data.callerId,
            callerName: data.callerName,
            taskId: data.taskId,
            callType: data.type,
          },
          android: {
            priority: "high",
            notification: {
              priority: "max",
              channelId: "xolv_calls",
            },
          },
        });
      }

      // 30秒后自动 timeout（若接收方仍未响应）
      await new Promise((resolve) => setTimeout(resolve, 30000));
      const freshSnap = await snap.ref.get();
      if (freshSnap.data()?.status === "ringing") {
        await snap.ref.update({ status: "timeout" });
      }
    } catch (e) {
      console.error("onCallCreated 出错:", e);
    }
  });

// ==========================================
// 🤖 AI 助手：润色任务描述（Google Gemini）
// ==========================================
exports.improveTaskDescription = onCall({ secrets: ["GEMINI_API_KEY"] }, async (request) => {
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
exports.suggestTaskPrice = onCall({ secrets: ["GEMINI_API_KEY"] }, async (request) => {
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
// 🪪 KYC 通过后：用 Gemini Vision 读取 IC 正面，提取姓名/IC号并计算年龄
// ==========================================
exports.extractICData = onCall({ secrets: ["GEMINI_API_KEY"] }, async (request) => {
  const { uid, icFrontUrl, selfieUrl } = request.data;
  if (!uid || !icFrontUrl) {
    throw new Error("缺少必要参数 uid 或 icFrontUrl");
  }

  // 下载 IC 正面图片并转 base64
  const imgResponse = await fetch(icFrontUrl);
  const imgBuffer = Buffer.from(await imgResponse.arrayBuffer());
  const base64Image = imgBuffer.toString("base64");
  const mimeType = imgResponse.headers.get("content-type") || "image/jpeg";

  // 用 Gemini Vision 读取 IC 资料
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

  const result = await model.generateContent([
    {
      inlineData: {
        mimeType,
        data: base64Image,
      },
    },
    `这是一张马来西亚身份证（MyKad）图片。
请提取以下资料并只返回 JSON，不要其他文字：
{
  "fullName": "身份证上的全名",
  "icNumber": "身份证号码（格式：XXXXXX-XX-XXXX）"
}
如果看不清楚就返回 {"fullName": "", "icNumber": ""}`,
  ]);

  const text = result.response.text().trim();
  const clean = text.replace(/```json|```/g, "").trim();
  const { fullName, icNumber } = JSON.parse(clean);

  // 从 IC 号码（YYMMDD-XX-XXXX）计算年龄
  let age = 0;
  if (icNumber && icNumber.length >= 6) {
    const digits = icNumber.replace(/-/g, "");
    const yy = parseInt(digits.substring(0, 2));
    const mm = parseInt(digits.substring(2, 4));
    const dd = parseInt(digits.substring(4, 6));
    const fullYear = yy <= 30 ? 2000 + yy : 1900 + yy;
    const birthDate = new Date(fullYear, mm - 1, dd);
    const today = new Date();
    age = today.getFullYear() - birthDate.getFullYear();
    const m = today.getMonth() - birthDate.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) age--;
  }

  // 写入 /users/{uid}：用于个人中心与任务卡片展示
  await db.collection("users").doc(uid).set(
    {
      verifiedName: fullName,
      verifiedAge: age,
      verifiedAvatarUrl: selfieUrl || "",
      kyc_status: "approved",
    },
    { merge: true }
  );

  // IC 号码属于敏感个人资料，只写入审核专用文档（非公开可读）
  await db.collection("kyc_applications").doc(uid).set(
    { verifiedIC: icNumber },
    { merge: true }
  );

  return { fullName, age, icNumber };
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

// ==========================================
// 🎙️📹 Agora 语音/视频通话：生成临时 RTC Token
// ==========================================
exports.generateAgoraToken = onCall(
  { secrets: ["AGORA_APP_CERTIFICATE"] },
  async (request) => {
    const { channelName, uid } = request.data;

    if (!channelName) throw new Error("Channel name is required");

    const appId = "58d89cd4cb224655959281b0ead870b6";
    const appCertificate = process.env.AGORA_APP_CERTIFICATE;

    // Token 有效期 1 小时
    const expirationTimeInSeconds = 3600;
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid || 0,
      RtcRole.PUBLISHER,
      privilegeExpiredTs,
      privilegeExpiredTs
    );

    return { token, channelName, uid: uid || 0 };
  }
);
