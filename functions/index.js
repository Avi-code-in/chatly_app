const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendChatNotification = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const messageData = snapshot.data();
    const chatId = context.params.chatId;
    const senderId = messageData.senderId;
    const messageText = messageData.text || '📷 Photo';

    // Get chat participants
    const chatDoc = await admin.firestore()
      .collection('chats').doc(chatId).get();
    const participants = chatDoc.data().participants;
    const receiverId = participants.find(id => id !== senderId);

    // Get receiver's FCM token
    const userDoc = await admin.firestore()
      .collection('users').doc(receiverId).get();
    const fcmToken = userDoc.data().fcmToken;

    if (!fcmToken) {
      console.log('No FCM token for user:', receiverId);
      return null;
    }

    // Get sender name
    const senderDoc = await admin.firestore()
      .collection('users').doc(senderId).get();
    const senderName = senderDoc.data().name || 'Someone';

    // Send notification
    const payload = {
      notification: {
        title: senderName,
        body: messageText,
        sound: 'default',
      },
      data: {
        chatId: chatId,
        type: 'chat',
      },
    };

    return admin.messaging().sendToDevice(fcmToken, payload);
  });
