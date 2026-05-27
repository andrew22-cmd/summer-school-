# GitHub Actions: Firebase Cloud Messaging Workflow

A GitHub Actions workflow for sending Firebase Cloud Messaging (FCM) push notifications via GitHub interface.

## What It Does

This workflow:
- ✅ Sends FCM push notifications to a topic
- ✅ Accepts inputs: title, body, topic
- ✅ Uses Firebase Admin SDK
- ✅ Reads Firebase credentials from GitHub Secrets
- ✅ Logs success/failure messages
- ✅ Cleans up sensitive files automatically

## Setup

### Step 1: Add Firebase Service Account to GitHub Secrets

1. Go to your GitHub repo
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `FIREBASE_SERVICE_ACCOUNT`
5. Value: Paste the contents of `serviceAccountKey.json` (the entire JSON)
6. Click **Add secret**

### Step 2: Verify Workflow File

The workflow file is located at:

```text
.github/workflows/send_notification.yml
```

## How to Use

### Method 1: GitHub Web Interface (Easy)

1. Go to your GitHub repo
2. Click **Actions** tab
3. Select **Send Firebase Cloud Messaging Notification**
4. Click **Run workflow** button
5. Fill in:
   - **title**: "New Task" (or any text)
   - **body**: "You received a new task" (or any text)
   - **topic**: "all" (or "members", "managers", etc.)
6. Click **Run workflow**
7. Wait for the workflow to complete
8. Check the logs for success/failure

### Method 2: GitHub CLI

```bash
gh workflow run send_notification.yml \
  -f title="New Task" \
  -f body="You received a new task" \
  -f topic="all"
```

## Workflow Inputs

| Input | Description | Example |
|-------|-------------|---------|
| **title** | Notification title | "New Task" |
| **body** | Notification body/message | "You received a new task" |
| **topic** | FCM topic to send to | "all", "members", "managers" |

## FCM Topics

Send notifications to groups of users by topic:

```text
all          → All app users
members      → Only members
managers     → Only managers
summer-2024  → Specific group
```

Users subscribe to topics in your Flutter app:

```dart
// Subscribe to topic
await FirebaseMessaging.instance.subscribeToTopic('members');

// Unsubscribe from topic
await FirebaseMessaging.instance.unsubscribeFromTopic('members');
```

## What Happens

1. **Setup Node.js** - GitHub runner prepares Node.js environment
2. **Install firebase-admin** - Installs Firebase Admin SDK
3. **Create service account** - Reads from GitHub Secret and creates temporary file
4. **Send notification** - Sends FCM message to the topic
5. **Cleanup** - Deletes temporary files (security)
6. **Log results** - Shows success or error message

## Success Example

When successful, you'll see logs like:

```text
📤 Sending FCM notification...
   Title: New Task
   Body: You received a new task
   Topic: all

✅ Notification sent successfully!
   Message ID: 0:1716...7f81%a8c...

🎉 FCM notification workflow completed successfully!
```

## Error Example

If it fails, you'll see:

```text
❌ Failed to send notification:
   Error: Missing service account credentials
```

**Common errors:**
- `FIREBASE_SERVICE_ACCOUNT` secret not set → Go to GitHub Settings → Secrets
- Invalid JSON in secret → Copy-paste entire serviceAccountKey.json
- Topic doesn't have subscribers → No error, but no delivery

## Security

✅ **Safe to use:**
- Service account credentials stored in GitHub Secrets
- Temporary files cleaned up automatically
- No credentials in logs or code
- Credentials never exposed publicly

## Testing

### Test 1: Send notification to all users

1. Click **Actions** → **Send Firebase Cloud Messaging Notification**
2. Run workflow with:
   - Title: "Test"
   - Body: "This is a test"
   - Topic: "all"
3. Check your phone → Should see notification (if app has FCM set up)

### Test 2: Send to specific topic

1. Run workflow with:
   - Title: "Member Update"
   - Body: "New member features available"
   - Topic: "members"
2. Only users subscribed to "members" will receive it

## Logs

After running the workflow:

1. Go to **Actions** tab
2. Click on the workflow run
3. Click on **send-notification** job
4. Expand each step to see logs
5. Look for ✅ or ❌ indicators

## Troubleshooting

**Workflow doesn't appear in Actions tab?**
- Make sure file is at: `.github/workflows/send_notification.yml`
- Commit and push to main branch

**"Secret not found" error?**
- Go to repo Settings → Secrets and variables → Actions
- Make sure secret name is exactly: `FIREBASE_SERVICE_ACCOUNT`

**"Invalid credentials" error?**
- Re-copy the entire `serviceAccountKey.json` content
- Make sure it's valid JSON (no extra quotes or escapes)

**"Topic has no subscribers" warning?**
- This is normal if no users subscribed to that topic
- Notification is queued but won't deliver
- Check your Flutter app topic subscriptions

## Advanced: Custom Topics

You can use any topic name:

```text
notifications-2024
urgent
announcements
classroom-3
```

Just make sure your Flutter app subscribes to the same topics.

## Files

- **Workflow:** `.github/workflows/send_notification.yml`
- **Backend:** `notifications-backend/` (uses firebase-admin)
- **Secret:** Settings → Secrets (FIREBASE_SERVICE_ACCOUNT)

## Integration with Flutter

Your Flutter app needs to:

1. **Initialize FCM:**

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

final messaging = FirebaseMessaging.instance;
```

2. **Subscribe to topics:**

```dart
await messaging.subscribeToTopic('members');
await messaging.subscribeToTopic('all');
```

3. **Handle notifications:**

```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('Got notification: ${message.notification?.title}');
});
```

## Summary

✅ Easy to use - No terminal needed
✅ Web interface - Click and run
✅ Secure - Secrets stored safely
✅ Flexible - Send to any topic
✅ Fast - Notifications send instantly
✅ Logged - See all results

**Ready to send notifications!** 🚀
