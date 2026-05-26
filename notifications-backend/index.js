const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const path = require('path');

const PORT = process.env.PORT || 3000;
const app = express();

app.use(cors());
app.use(express.json({ limit: '1mb' }));

let serviceAccount;
try {
  serviceAccount = require(path.join(__dirname, 'serviceAccountKey.json'));
} catch (error) {
  console.error('Missing serviceAccountKey.json in backend root.');
  console.error('Please add your Firebase service account file before starting the server.');
  throw error;
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

app.get('/', (_req, res) => {
  res.status(200).send('Notifications Server Running 🚀');
});

app.post('/send-notification', async (req, res) => {
  try {
    const { token, title, body } = req.body || {};

    if (!token || !title || !body) {
      return res.status(400).json({
        success: false,
        error: 'token, title, and body are required',
      });
    }

    const message = {
      token,
      notification: {
        title,
        body,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'default',
          priority: 'max',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    console.log('Sending FCM notification:', {
      tokenPreview: `${String(token).slice(0, 10)}...`,
      title,
      body,
    });

    const response = await admin.messaging().send(message);

    console.log('FCM sent successfully:', response);

    return res.status(200).json({
      success: true,
      messageId: response,
    });
  } catch (error) {
    console.error('Failed to send notification:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to send notification',
    });
  }
});

app.use((err, _req, res, _next) => {
  console.error('Unhandled server error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
  });
});

app.listen(PORT, () => {
  console.log(`Notifications server running on port ${PORT}`);
});