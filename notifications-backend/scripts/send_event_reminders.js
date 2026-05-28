const admin = require('firebase-admin');
const { Timestamp } = require('firebase-admin/firestore');

// Initialize firebase-admin using application default credentials
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Helper: get tomorrow's date range in Cairo timezone (UTC+3)
function getTomorrowRangeCairo() {
  const offsetHours = 3; // Cairo (UTC+3)
  const now = new Date();
  // shift current time to Cairo
  const cairoNow = new Date(now.getTime() + offsetHours * 3600 * 1000);

  const year = cairoNow.getUTCFullYear();
  const month = cairoNow.getUTCMonth();
  const day = cairoNow.getUTCDate() + 1; // tomorrow in Cairo

  // The UTC timestamps that correspond to Cairo's local start and end of that day
  const startUtcMillis = Date.UTC(year, month, day, -offsetHours, 0, 0);
  const endUtcMillis = Date.UTC(year, month, day, 23 - offsetHours, 59, 59);

  const start = new Date(startUtcMillis);
  const end = new Date(endUtcMillis);

  return { start: Timestamp.fromDate(start), end: Timestamp.fromDate(end) };
}

async function findEventsTomorrow() {
  const { start, end } = getTomorrowRangeCairo();

  // Adjust collection path to match your Firestore structure. Commonly: 'events'
  const eventsRef = db.collection('events');

  // Query only by time window first, then filter out already-reminded events in code
  const q = eventsRef.where('startAt', '>=', start).where('startAt', '<=', end);
  const snap = await q.get();
  const events = [];
  snap.forEach(doc => {
    const data = doc.data() || {};
    // Skip if reminder already sent
    if (data.reminderSent === true) return;
    events.push({ id: doc.id, ref: doc.ref, ...data });
  });
  return events;
}

async function sendReminderForEvent(event) {
  // Expect event.topic or construct topic name from event.id
  const topic = event.topic || `event_${event.id}`;

  const payload = {
    notification: {
      title: `Reminder: ${event.title || 'Upcoming event'}`,
      body: event.description ? `${event.description}` : `Happening tomorrow at ${new Date(event.startAt._seconds * 1000).toUTCString()}`,
    },
    data: {
      eventId: event.id,
      type: 'event_reminder',
    },
  };

  console.log(`Sending reminder to topic: ${topic}`);
  const res = await admin.messaging().sendToTopic(topic, payload);
  console.log('FCM result:', res);

  // Mark reminder as sent on the event document to avoid double-sends
  try {
    if (event.ref && event.ref.update) {
      await event.ref.update({ reminderSent: true, reminderSentAt: admin.firestore.FieldValue.serverTimestamp() });
    } else {
      // Fallback: update by id
      await db.collection('events').doc(event.id).update({ reminderSent: true, reminderSentAt: admin.firestore.FieldValue.serverTimestamp() });
    }
  } catch (err) {
    console.error('Failed to mark reminderSent for event', event.id, err);
  }
}

async function main() {
  try {
    const events = await findEventsTomorrow();
    if (!events.length) {
      console.log('No events happening tomorrow.');
      return;
    }

    for (const evt of events) {
      try {
        await sendReminderForEvent(evt);
      } catch (err) {
        console.error('Failed to send reminder for event', evt.id, err);
      }
    }
  } catch (err) {
    console.error('Script failed', err);
    process.exitCode = 1;
  }
}

// Run when executed
if (require.main === module) {
  main();
}
