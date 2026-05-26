# Push Notifications System Documentation

## Overview

This is a complete push notifications system integrated into the Summer School Flutter app using Firebase Cloud Messaging (FCM) and Firestore.

## Architecture

### 1. **Data Models**

#### `AppNotificationModel` (lib/models/app_notification_model.dart)
- Represents a notification created by a manager
- Stored in Firestore `notifications` collection
- Fields: id, title, body, targetRole (optional), targetStage (optional), createdBy, createdAt

#### `UserNotificationModel` (lib/models/user_notification_model.dart)
- Represents a notification as seen by individual users
- Stored in Firestore `user_notifications` collection
- Fields: id, notificationId, userId, title, body, sender, targetRole, targetStage, isRead, createdAt, readAt

### 2. **Services**

#### `NotificationService` (lib/services/notification_service.dart)
Handles Firestore operations:
- `createNotification()` - Creates new notification in manager-created notifications
- `watchUserNotifications()` - Returns realtime stream of user's notifications
- `watchUnreadCount()` - Returns realtime stream of unread notification count
- `markAsRead()` - Marks single notification as read
- `isNotificationRelevantToUser()` - Checks if notification applies to user

#### `PushNotificationService` (lib/services/push_notification_service.dart)
Handles FCM and local notifications:
- `initialize()` - Sets up FCM, local notifications, and message handlers
- `syncCurrentUserToken()` - Stores user's FCM token in Firestore on login
- `clearCurrentUser()` - Removes token on logout
- Handles foreground, background, and terminated message states
- Shows local notifications in all app states

### 3. **Providers**

#### `NotificationProvider` (lib/providers/notification_provider.dart)
State management for notifications:
- Streams for notifications list and unread count
- Methods to mark notifications as read

#### `AuthProvider` (lib/providers/auth_provider.dart) - Enhanced
- Calls `PushNotificationService.syncCurrentUserToken()` after successful login
- Calls `PushNotificationService.clearCurrentUser()` on logout

### 4. **UI Screens**

#### `SendNotificationScreen` (lib/screens/notifications/send_notification_screen.dart)
- **Access**: Manager only
- **Features**:
  - Enter notification title and body
  - Select target audience (All, Managers, Member Managers, Members)
  - Filter by stage (when specific role selected)
  - Send button creates notification in Firestore

#### `NotificationCenterScreen` (lib/screens/notifications/notification_center_screen.dart)
- **Access**: All users
- **Features**:
  - Display unread count in app bar
  - List all notifications (newest first)
  - Visual distinction for unread vs read
  - Mark as read on tap or with button
  - Shows: title, body, sender, timestamp

### 5. **Cloud Function**

#### `sendNotificationToUsers` (functions/sendNotification.js)
Triggered when notification is created in Firestore:
1. Queries `user_tokens` collection based on targetRole and targetStage
2. Sends FCM message to all matching device tokens
3. Creates `user_notification` documents for each user
4. Handles batching for large audiences

## User Flow

### For Managers (Sending Notifications)

1. **Create Notification**:
   - Tap "Add Notification" from Manager Home
   - Navigate to `SendNotificationScreen`
   - Enter title and body
   - Select target role (All/Managers/Member Managers/Members)
   - Optionally filter by stage
   - Tap "Send"

2. **Behind the Scenes**:
   - `NotificationService.createNotification()` creates doc in `notifications` collection
   - Cloud Function triggers automatically
   - Cloud Function queries matching user tokens
   - FCM sends to all tokens
   - User notification records created in `user_notifications`

### For All Users (Receiving Notifications)

1. **Receive Notification**:
   - FCM message arrives on device
   - `PushNotificationService` handles it:
     - If app is open (foreground): Shows local notification
     - If app is backgrounded: Android/iOS handles, then opens when tapped
     - If app is terminated: Saved by OS, opens app when tapped

2. **View Notifications**:
   - Members: Tap "Notifications" from Members Home
   - Managers: Can send and view (add to notification center if needed)
   - `NotificationCenterScreen` shows all notifications
   - Notifications stream updates in realtime

3. **Mark as Read**:
   - Tap notification to view
   - Tap checkmark icon or auto-mark when opened
   - Updates Firestore record

## Firestore Collections

### `user_tokens`
```dart
{
  userId: string,
  token: string,
  role: string,
  stage: string,
  lastSyncedAt: timestamp
}
```

### `notifications`
```dart
{
  id: string,
  title: string,
  body: string,
  targetRole: string?, // null = all
  targetStage: string?, // null = all stages
  createdBy: string,
  createdAt: timestamp
}
```

### `user_notifications`
```dart
{
  id: string,
  notificationId: string,
  userId: string,
  title: string,
  body: string,
  sender: string,
  targetRole: string,
  targetStage: string,
  isRead: boolean,
  createdAt: timestamp,
  readAt: timestamp?
}
```

## Routing

### New Routes Added
- `/send-notification` → `SendNotificationScreen`
- `/notification-center` → `NotificationCenterScreen`

### Updated Menu Items
- **Manager Home**: "Add Notification" → `/send-notification`
- **Members Home**: New "Notifications" item → `/notification-center`

## Configuration

### Firebase Setup Required

1. **Enable Messaging in Firebase Console**:
   - Go to Project Settings → Cloud Messaging
   - Generate Android and APNs certificates if needed

2. **Android Configuration** (android/app/build.gradle):
   - Already includes Google Play Services (Firebase)
   - Cloud messaging plugin automatically configured

3. **iOS Configuration**:
   - Enable "Push Notifications" capability in Xcode
   - Upload APNs certificate to Firebase Console

4. **Web Support**:
   - Works with Firebase web SDK
   - Tokens managed separately for web platform

### Dependencies Added
```yaml
firebase_messaging: ^15.0.4
flutter_local_notifications: ^17.2.1+2
```

## Deployment Steps

### 1. Deploy Cloud Function

```bash
cd functions
npm install
firebase deploy --only functions:sendNotificationToUsers
```

### 2. Build and Run App

```bash
flutter pub get
flutter run
```

### 3. Test Workflow

1. **Admin Setup**:
   - Login as manager
   - Create test notification

2. **User Reception**:
   - Login with member account on another device
   - Verify notification received
   - Check notification center

## Key Features

✅ **Role-Based Targeting**: Send to specific roles or all users
✅ **Stage Filtering**: Filter by stage within role
✅ **Realtime Updates**: Notifications appear instantly
✅ **Foreground/Background Handling**: Works in all app states
✅ **Local Notifications**: Visible even if app closed
✅ **Mark as Read**: Track read status per user
✅ **Unread Count**: Badge with unread count in UI
✅ **Automatic Token Sync**: Tokens synced on login/logout
✅ **Persistent History**: All notifications saved in Firestore

## Debugging

### Check FCM Tokens
In Firestore Console, browse `user_tokens` collection to see:
- Which users have tokens
- Which roles/stages they're assigned
- Last sync time

### Monitor Cloud Function
In Firebase Console → Functions:
- View execution logs
- Check for errors
- Monitor latency

### View Notifications in Firestore
In Firestore Console:
- Browse `notifications` collection for created messages
- Browse `user_notifications` to see user delivery status

## Troubleshooting

### Notifications Not Received
1. Check user has valid FCM token in `user_tokens`
2. Verify `notification.targetRole` matches user's role
3. Check Cloud Function logs for errors
4. Verify device has internet connectivity
5. Check app has notification permission

### Tokens Not Syncing
1. Verify `AuthProvider.syncCurrentUserToken()` is called
2. Check Firebase auth is working
3. Verify Firestore permissions allow write to `user_tokens`
4. Check user role is correctly set in Firestore

### Cloud Function Not Triggering
1. Verify function is deployed: `firebase functions:list`
2. Check function logs in Firebase Console
3. Verify Firestore rules allow reads from `user_tokens`
4. Check that notification document is in correct collection

## Next Steps (Optional Enhancements)

- [ ] Add notification categories/tags for filtering
- [ ] Add scheduled notification sending
- [ ] Add rich media (images) to notifications
- [ ] Add notification actions (reply, snooze, etc.)
- [ ] Add notification analytics (delivery, open rate)
- [ ] Add template system for common notifications
- [ ] Add notification history/archive
