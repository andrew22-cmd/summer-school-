# Automatic In-App Notifications System

## Overview

The Summer School app now includes a **fully automatic, Firestore-only in-app notification system**. Notifications are generated automatically when managers or member managers perform certain actions, without requiring Firebase Messaging or Cloud Functions.

**Key Features:**
- ✅ Firestore-only (Spark plan compatible)
- ✅ Real-time delivery via snapshots
- ✅ Automatic triggers on action completion
- ✅ Role-based recipient targeting
- ✅ Unread count tracking
- ✅ In-app notification center

---

## System Architecture

### Firestore Collections

#### `notifications`
Stores notification definitions and metadata.

**Schema:**
```dart
{
  id: String,              // auto-generated doc ID
  title: String,           // "مهمة جديدة"
  body: String,            // "تم إضافة مهمة جديدة لك: ..."
  type: String,            // "task" | "attachment" | "event" | "schedule" | "visits" | "manual"
  relatedId: String,       // reference to task/attachment/event doc ID
  targetRoles: [String],   // ["member", "member_manager"] or []
  targetStages: [String],  // ["3", "4"] or []
  createdBy: String,       // sender user ID
  createdAt: Timestamp,
  isImportant: Boolean,
}
```

#### `user_notifications`
Stores per-user notification delivery and read state.

**Schema:**
```dart
{
  id: String,              // auto-generated doc ID
  notificationId: String,  // reference to notifications/{id}
  userId: String,          // recipient user ID
  isRead: Boolean,         // read state
  createdAt: Timestamp,
}
```

---

## Automatic Triggers

Notifications are automatically created when:

### 1. **Task Created**
**When:** Manager or member manager creates and assigns a task to someone

**Recipient:** The assigned user only

**Message:**
```
Title: "مهمة جديدة"
Body: "تم إضافة مهمة جديدة لك: [task title]"
```

**Code Location:** [lib/services/task_service.dart](lib/services/task_service.dart#L118-L148)

**Implementation:**
```dart
await _notificationService.createAutomaticNotification(
  sender: assignedBy,
  type: 'task',
  title: 'مهمة جديدة',
  body: 'تم إضافة مهمة جديدة لك: ${title.trim()}',
  targetUserId: assignedTo.id,  // Only assigned user
  relatedId: ref.id,
);
```

---

### 2. **Attachment Uploaded**
**When:** Manager or member manager uploads a file

**Recipients:** Determined by upload target:
- `all_servants` → all members + member managers
- `member_managers` → member managers only
- `managers` → managers only
- Can also target specific stage

**Message:**
```
Title: "ملف جديد"
Body: "تم رفع ملف جديد: [file title]"
```

**Code Location:** [lib/services/attachment_service.dart](lib/services/attachment_service.dart#L118-L175)

**Implementation:**
```dart
await notificationService.createAutomaticNotification(
  sender: senderUserModel,
  type: 'attachment',
  title: 'ملف جديد',
  body: 'تم رفع ملف جديد: $title',
  targetRoles: ['member', 'member_manager'],  // Based on upload target
  targetStages: [stage],                      // If stage-specific
  relatedId: docRef.id,
);
```

---

### 3. **Event Added**
**When:** Manager or member manager creates an event

**Recipients:** All users (broadcast)

**Message:**
```
Title: "حدث جديد"
Body: "تم إضافة حدث جديد: [event title]"
```

**Code Location:** [lib/services/event_service.dart](lib/services/event_service.dart#L21-L41)

**Implementation:**
```dart
await _notificationService.createAutomaticNotification(
  sender: senderUserModel,
  type: 'event',
  title: 'حدث جديد',
  body: 'تم إضافة حدث جديد: ${event.title}',
  relatedId: event.id,
);
```

---

### 4. **Weekly Schedule Updated**
**When:** Manager or member manager adds/updates weekly schedule for their stage

**Recipients:** All members in that stage

**Message:**
```
Title: "جدول محدث"
Body: "تم تحديث جدول المرحلة: [stage name]"
```

**Code Location:** [lib/services/weekly_schedule_service.dart](lib/services/weekly_schedule_service.dart#L38-L57)

**Implementation:**
```dart
await _notificationService.createAutomaticNotification(
  sender: senderUserModel,
  type: 'schedule',
  title: 'جدول محدث',
  body: 'تم تحديث جدول المرحلة: ${item.stage}',
  targetStages: [item.stage],
  relatedId: item.id,
);
```

---

## Role-Based Behavior

### Manager
✅ Can trigger automatic notifications for:
- Tasks assigned to any user
- Attachments targeting any roles/stages
- Events (broadcast to all)
- Schedules for any stage

✅ Automatic notification parameters:
- Can target specific roles
- Can target specific stages
- Can target both roles AND stages
- If no targets specified → broadcasts to all users

### Member Manager
✅ Can trigger automatic notifications for:
- Tasks assigned to members in their stage only
- Attachments targeting their stage members
- Events (broadcast to all)
- Schedules for their stage only

⚠️ Automatic restrictions:
- Can ONLY notify members in their own stage
- Cannot target other stages or member managers
- System automatically enforces stage restriction

### Member
❌ Cannot trigger automatic notifications

---

## NotificationService API

### Creating Notifications

#### `createAutomaticNotification()`
Creates an automatic notification with automatic recipient resolution.

```dart
Future<void> createAutomaticNotification({
  required UserModel sender,              // The user creating the action
  required String type,                   // 'task'|'attachment'|'event'|'schedule'|'visits'|'manual'
  required String title,                  // Notification title
  required String body,                   // Notification body
  String? targetUserId,                   // For single-user targeting (tasks)
  List<String>? targetRoles,              // ['member', 'member_manager', 'manager']
  List<String>? targetStages,             // ['3', '4']
  String? relatedId,                      // Reference to task/attachment/event doc
}) async
```

**Parameters:**
- `sender`: UserModel of the person creating the action
- `type`: Notification type for categorization
- `title` / `body`: Notification text (should be in Arabic)
- `targetUserId`: For single-recipient (leaves other targets empty)
- `targetRoles`: Roles to target (manager auto-resolves if member_manager)
- `targetStages`: Stages to target (member_manager auto-restricts to own stage)
- `relatedId`: Store reference to original resource for detail linking

**Automatic Resolution:**
- Member role attempts → throws exception
- Member manager → auto-restricts to own stage + member role only
- Manager → respects specified targets or broadcasts if empty
- Resolves actual user IDs from `users` collection
- Creates per-user entries in batches (400 at a time for Firestore limits)

---

## Notification Center UI

### Screens

#### `NotificationCenterScreen`
Main notifications inbox with real-time updates.

**Features:**
- Real-time list via `watchNotificationCenter()`
- Unread count badge in app bar
- Mark as read on tap
- Icon: high-importance notifications shown with red badge
- Date formatting: "dd/MM/yyyy - hh:mm a"
- Empty state message

**Navigation:**
- Added to app bar notification icon in:
  - Manager Home Screen
  - Member Home Screen
  - Routes: `AppRoutes.notificationCenter`

#### `SendNotificationScreen`
Manual notification sending (for manager/member manager only).

**Features:**
- Title/body input (max 90/500 chars)
- Important toggle with icon preview
- Role/stage chip selectors (manager only)
- Auto-restriction for member manager to own stage
- Success/error feedback via snackbar

---

## Unread Notifications Badge

### Home Screens

#### Manager Home
App bar shows unread count badge linked to `watchUnreadCount()`

#### Member Home
App bar shows unread count badge + link to notification center

**Live Update:**
Both use real-time streams, so badge updates instantly when new notifications arrive.

---

## Real-Time Architecture

All notification streams use Firestore `snapshots()`:

```dart
// Watch user's unread notifications
Stream<int> watchUnreadCount(String userId)

// Watch user's notifications (joined with details)
Stream<List<NotificationCenterItemModel>> watchNotificationCenter(String userId)

// Watch available stages for filtering
Stream<List<String>> watchAvailableStages()
```

**No Compound Indexes Needed:**
- Sorting done client-side to avoid Firestore composite index requirements
- Filtering done client-side
- Spark plan compatible ✅

---

## Integration Points

### To Enable Automatic Notifications

When creating/updating actions, pass `senderUserModel` and optionally `notificationService`:

#### Task Creation (Provider)
```dart
// In TaskProvider.createTask():
await _service.createTask(
  assignedBy: sender,
  assignedTo: recipient,
  title: title,
  description: description,
  dueDate: dueDate,
  // Notification triggered automatically in TaskService
);
```

#### Attachment Upload (Provider)
```dart
// In AttachmentProvider.uploadAttachmentWithProgress():
await _service.uploadAttachment(
  file: file,
  fileName: fileName,
  title: title,
  stage: stage,
  uploadedBy: uploadedBy,
  targetRole: selectedRole,
  senderUserModel: currentUser,           // PASS USER MODEL
  notificationService: NotificationService(), // PASS SERVICE
);
```

#### Event Creation (Provider)
```dart
// In EventProvider.createEvent():
await _service.createEvent(
  event: eventModel,
  senderUserModel: currentUser,  // PASS USER MODEL
);
```

#### Schedule Update (Provider)
```dart
// In ScheduleProvider.addItem() or updateItem():
await _service.addItem(
  item: scheduleItem,
  senderUserModel: currentUser,  // PASS USER MODEL
);
```

---

## Data Model

### AppNotificationModel
```dart
class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final List<String> targetRoles;
  final List<String> targetStages;
  final String createdBy;
  final DateTime createdAt;
  final bool isImportant;
  final String type;      // NEW: notification type
  final String relatedId; // NEW: reference to original resource
  
  // Methods: toMap(), fromMap()
}
```

### UserNotificationModel
```dart
class UserNotificationModel {
  final String id;
  final String notificationId;
  final String userId;
  final bool isRead;
  final DateTime createdAt;
}
```

### NotificationCenterItemModel (UI Model)
```dart
class NotificationCenterItemModel {
  final String userNotificationId;
  final String notificationId;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final bool isImportant;
}
```

---

## Spark Plan Compatibility

✅ **No Cloud Functions** - All logic runs in Flutter app
✅ **No Firebase Messaging** - In-app only
✅ **No Composite Indexes** - Client-side sorting/filtering
✅ **No Large Batch Writes** - Batches limited to 400 docs
✅ **Realtime via Snapshots** - Standard Firestore streams

**Firestore Read/Write Estimates:**
- Task creation: 1 write + (1 to N) writes to user_notifications (N = recipients)
- Attachment upload: 1 write + (1 to N) writes
- Event creation: 1 write + (1 to all users) writes
- Schedule update: 1 write + (stage members) writes
- Mark notification as read: 1 write
- Watch streams: 1 read per snapshot + 1 read per notification detail fetch

---

## Firestore Security Rules (Recommended)

```json
{
  "rules": {
    "notifications": {
      ".read": "request.auth != null",
      ".write": "request.auth.uid == resource.data.createdBy && 
                 (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'manager' ||
                  get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'member_manager')"
    },
    "user_notifications": {
      ".read": "request.auth.uid == resource.data.userId",
      ".write": "request.auth.uid == resource.data.userId ||
                 get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['manager', 'member_manager']"
    }
  }
}
```

---

## Testing Automatic Notifications

### Manual Test Steps

1. **Create Task**
   - Login as manager
   - Go to Manage Tasks
   - Assign task to a member
   - Switch to member account
   - Check notification center → should show "مهمة جديدة"

2. **Upload Attachment**
   - Login as manager
   - Go to Manage Attachments
   - Upload file for "all servants"
   - Switch to member account
   - Check notification center → should show "ملف جديد"

3. **Add Event**
   - Login as manager
   - Go to Add Event
   - Create event
   - Check any member's notifications → should show "حدث جديد"

4. **Update Schedule**
   - Login as member manager
   - Go to Schedule
   - Add/update schedule item for own stage
   - Check members in that stage's notifications → should show "جدول محدث"

---

## Debugging

### Enable Logs
All automatic notification creation logs print to console:
```
[NotificationService] automatic task notification created id=xyz recipients=5
[TaskService] notification error: exception details...
```

### Check Firestore
1. Firebase Console → Firestore → `notifications` collection
   - Verify docs created with correct `type` field
   - Check `targetRoles`, `targetStages`, `relatedId` values

2. `user_notifications` collection
   - Verify per-user docs created
   - Check `isRead` status after mark-as-read

3. Real-time updates
   - Open notification center in two browser windows
   - Create notification from one window
   - Other window should update instantly

---

## Future Enhancements

- [ ] Visit reminders automatic notifications
- [ ] Notification categories/filtering
- [ ] Notification expiration (cleanup old docs)
- [ ] Push notifications on top of in-app (if Blaze plan adopted)
- [ ] Email digests of unread notifications
- [ ] Notification preferences per user

---

## Summary

This automatic notification system enables:
- **Zero management** - Notifications created automatically
- **Smart targeting** - Role-based and stage-specific delivery
- **Real-time** - Instant updates via Firestore snapshots
- **Lightweight** - Spark plan compatible, no backend required
- **User-friendly** - Beautiful in-app notification center with unread badges

The system is production-ready and automatically integrated into all supported actions.
