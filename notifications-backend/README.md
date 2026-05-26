# Notifications Backend

A clean Node.js + Express backend for sending Firebase Cloud Messaging (FCM) push notifications using Firebase Admin SDK.

## Features

- Express server
- Firebase Admin SDK
- CORS enabled
- POST `/send-notification`
- GET `/` health check
- Production-ready async/await error handling

## Requirements

- Node.js 18+
- Firebase service account JSON file

## Installation

1. Open this folder:
   - `notifications-backend`

2. Install dependencies:

```bash
npm install
```

3. Add your Firebase service account file:

- Download it from Firebase Console
- Rename it to `serviceAccountKey.json`
- Place it in the backend root folder

Your folder should look like this:

```text
notifications-backend/
├── index.js
├── package.json
├── .gitignore
├── README.md
└── serviceAccountKey.json
```

## Run the server

```bash
npm start
```

The server runs on:

```text
http://localhost:3000
```

## API

### GET /

Returns:

```text
Notifications Server Running 🚀
```

### POST /send-notification

Send a push notification to a single FCM token.

#### Request body

```json
{
  "token": "FCM_TOKEN",
  "title": "New Task",
  "body": "You received a new task"
}
```

#### Success response

```json
{
  "success": true,
  "messageId": "firebase-message-id"
}
```

#### Error response

```json
{
  "success": false,
  "error": "error message"
}
```

## Postman Test

1. Open Postman
2. Create a new request
3. Set method to `POST`
4. Use URL:

```text
http://localhost:3000/send-notification
```

5. Go to **Body** → **raw** → **JSON**
6. Paste:

```json
{
  "token": "YOUR_FCM_TOKEN",
  "title": "New Task",
  "body": "You received a new task"
}
```

7. Click **Send**

## Deployment

This backend is ready for deployment on:

- Render
- Railway
- Cyclic

### Important for deployment

Make sure your deployment environment includes:
- `serviceAccountKey.json`
- Node.js environment
- Port support via `process.env.PORT`

## Notes

- `.gitignore` excludes `node_modules` and `serviceAccountKey.json`
- Keep the service account file private
- Do not commit `serviceAccountKey.json` to GitHub
