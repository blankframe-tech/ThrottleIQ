# P6: Emergency Contact & Crash Detection

## Overview

P6 implements a comprehensive motorcycle safety system that detects crashes in real-time, alerts emergency contacts, and provides live ride tracking via shareable links.

## Features

### 1. Advanced Crash Detection (Signal Fusion)

**Location:** `app/lib/features/ride/domain/calculators/event_detector.dart`

The crash detector uses multi-signal analysis to avoid false positives:

- **Accel Spike Detection:** >8g threshold (80 m/s²)
- **Jerk Spike Detection:** >10 m/s³ during spike window
- **Speed Drop Detection:** Speed → 0 m/s within 2 seconds
- **False Positive Avoidance:**
  - Potholes: Single spike without jerk+speed-drop = NO alert
  - Hard braking: Sustained decel without speed-drop = NO alert
  - GPS noise: Random spikes without pattern = NO alert

**Test Coverage:** `app/test/calculators/crash_detector_test.dart`
- ✅ Pothole (single spike) - does NOT trigger
- ✅ Hard brake alone - does NOT trigger
- ✅ Actual crash (spike + jerk + speed-drop) - DOES trigger
- ✅ GPS noise - does NOT trigger
- ✅ Alert TTL clearing
- ✅ Fatigue alert throttling

### 2. Crash Detection UI (60s Countdown)

**Location:** `app/lib/features/ride/presentation/providers/ride_recording_provider.dart`

When crash is detected:
1. **Full-screen alert** displays "Crash Detected - Are You OK?"
2. **Loud sound + max vibration** for immediate attention
3. **60-second countdown timer** with "I'm OK" button
4. **Auto-escalation:** If no response → notify emergency contacts

**Implementation Details:**
- Countdown state tracked in `RideRecordingState.crashCountdown`
- UI renders full-screen modal with large countdown
- "I'm OK" button triggers `dismissCrashAlert()` → logs false positive → resumesride
- No response → `_handleCrashNotification()` writes to Firestore → Cloud Function triggers

### 3. Emergency Contacts CRUD

**Location:**
- Entity: `app/lib/features/profile/domain/entities/emergency_contact_entity.dart`
- Provider: `app/lib/features/profile/presentation/providers/emergency_contacts_provider.dart`

**Features:**
- Add/edit/delete contacts with name, phone, email
- Stored in Firestore: `/users/{uid}/emergencyContacts/{contactId}`
- Real-time updates via Riverpod StreamProvider
- Sorted by creation date (newest first)

**Firestore Structure:**
```json
{
  "name": "Mom",
  "phone": "+1-555-0100",
  "email": "mom@example.com",
  "createdAt": "2024-01-15T10:30:00Z"
}
```

### 4. Live Session Sharing

**Location:**
- Entity: `app/lib/features/ride/domain/entities/live_session_entity.dart`
- Provider: `app/lib/features/ride/presentation/providers/ride_recording_provider.dart`
- Publishing logic: `_publishLiveSession()` every 10 seconds

**Features:**
- **Unguessable Token:** 32-char random alphanumeric string
- **Share Link:** `https://throttleiq.app/live/{token}` (via `share_plus`)
- **Live Updates:** Every 10 seconds to Firestore
- **Auto-Expiry:** 24-hour TTL on live session documents

**Firestore Structure:**
```json
{
  "token": "AbCdEfGhIjKlMnOpQrStUvWxYz01234567",
  "uid": "user123",
  "rideId": "ride456",
  "active": true,
  "lastLat": 40.7128,
  "lastLng": -74.0060,
  "speedMs": 15.5,
  "batteryPct": 87,
  "status": "riding",  // riding | paused | crash | completed
  "updatedAt": "2024-01-15T10:30:00Z",
  "expiresAt": "2024-01-16T10:30:00Z"
}
```

### 5. Live Viewer (Static HTML)

**Location:** `public/live-viewer.html`

**Features:**
- **No Login Required:** Token-based access (capability-based security)
- **Real-time Updates:** Firebase Firestore SDK listening
- **Status Banner:** Color-coded (green=riding, amber=paused, red=CRASH, blue=completed)
- **Statistics:** Speed, battery %, latitude, longitude
- **Location Pin:** Shows last known coordinates
- **Stale Data Warning:** "No updates for 30+ seconds"
- **Share Link Copy:** Easy redistribution

**Security Model:**
- Token is the capability → only token holders can view
- Firestore rules: `allow read: if true` for `/liveSessions/{token}`
- No authentication required for viewer

### 6. Cloud Function (Crash Notifications)

**Location:** `functions/src/crash-notifications.ts`

**Triggers:**
- On-write to `/crashNotifications/{documentId}`
- Scheduled escalation every 15 minutes (Pub/Sub)

**Behavior:**

1. **Initial Alert (Immediate):**
   - Fetch user's emergency contacts
   - Send SMS to all phone numbers
   - Send email to all email addresses
   - Log contact attempts
   - Mark status → `contacted`

2. **Escalation (15 minutes):**
   - Check for `status='contacted'` with `contactedAt` >15min old
   - Send follow-up escalation alert
   - Mark status → `escalated`
   - (v1 contacts-only; future: call emergency services)

**MOCK Implementation (Update for Production):**
```typescript
// TODO: Integrate with Twilio for SMS
// TODO: Integrate with SendGrid or Firebase Email
// TODO: Future v2: Emergency services integration (911/999/112)
```

**Firestore Structure:**
```json
{
  "uid": "user123",
  "rideId": "ride456",
  "timestamp": "2024-01-15T10:30:00Z",
  "lastLat": 40.7128,
  "lastLng": -74.0060,
  "status": "pending",  // pending | contacted | escalated | acknowledged
  "contactedAt": "2024-01-15T10:31:00Z",
  "escalatedAt": null
}
```

## Firestore Rules

**Location:** `firestore.rules`

**Key Rules:**
```firestore
// Live sessions - anyone with token can read
match /liveSessions/{token} {
  allow read: if true;  // Capability-based access
  allow create: if request.auth.uid == request.resource.data.uid;
  allow update: if request.auth.uid == resource.data.uid;
}

// Emergency contacts - only user can read/write
match /users/{uid}/emergencyContacts/{contactId} {
  allow read, write: if request.auth.uid == uid;
}

// Crash notifications - user can write and read own
match /crashNotifications/{documentId} {
  allow write: if request.auth.uid == request.resource.data.uid;
  allow read: if request.auth.uid == resource.data.uid;
}
```

## Implementation Integration Points

### ride_recording_provider.dart Changes:

1. **Import additions:**
   ```dart
   import 'package:cloud_firestore/cloud_firestore.dart';
   import '../../domain/entities/live_session_entity.dart';
   ```

2. **State changes:**
   - `crashDetected: bool` - is crash alert showing?
   - `crashCountdown: int` - seconds remaining (60→0)
   - `liveSessionToken: String?` - current share token

3. **New methods:**
   - `_onCrashDetected()` - show alert, start countdown
   - `dismissCrashAlert()` - user tapped "I'm OK"
   - `_handleCrashNotification()` - auto-trigger if countdown expires
   - `_publishLiveSession()` - update Firestore every 10s
   - `_updateLiveSessionStatus()` - set riding/paused/crash/completed

4. **Hook into existing flow:**
   - `_onPosition()` passes `accel` to detector
   - Detector returns `RideAlert.crash` → calls `_onCrashDetected()`
   - `startRide()` calls `_startLiveSessionPublishing()`
   - `stopRide()` sets status → `completed`

## Dependencies Added

**pubspec.yaml:**
```yaml
share_plus: ^8.1.0      # Link sharing
battery_plus: ^1.4.1    # Battery percentage
cloud_firestore: ^4.14.0  # (already present)
```

**functions/package.json:**
```json
{
  "firebase-admin": "^12.0.0",
  "firebase-functions": "^4.8.0"
}
```

## Test Fixtures

**Scenario 1: Pothole (False Positive Avoidance)**
```
Input:  accel=[9.0, 0, 0], jerk=[5.0, 0, 0], speed=[10.0, 9.5, 9.4]
Result: NO CRASH (no jerk spike, no speed drop)
```

**Scenario 2: Hard Brake (False Positive Avoidance)**
```
Input:  accel=[-4.0], jerk=[-5.0], speed=[8.0, 7.7, 7.4, ...]
Result: NO CRASH (no accel spike >8g, speed doesn't drop to 0)
```

**Scenario 3: Actual Crash**
```
Input:  accel=[10.0, 9.5, -5.0], jerk=[0, 12.0, -8.0], speed=[15.0, 14.5, 0.5]
Result: CRASH (accel >8g + jerk >10 + speed→0 in 2s)
```

**Scenario 4: GPS Noise (False Positive Avoidance)**
```
Input:  Random spikes, high speed maintained
Result: NO CRASH (no sustained pattern)
```

## Token Expiry (TTL)

- Live sessions auto-delete after 24 hours
- Cloud Firestore TTL policy on `/liveSessions` collection
- Expired links show "Session not found or has expired"

## Future Enhancements (v2+)

- [ ] Emergency services integration (911/999/112)
- [ ] Contact acknowledgment feedback
- [ ] Ride replay with crash timestamp
- [ ] Machine learning crash prediction (before impact)
- [ ] Anonymous hazard reporting
- [ ] Integration with insurance companies
- [ ] Automated 911 call with GPS location
- [ ] Helmet-mounted crash cam integration

## Deployment Checklist

- [ ] Run tests: `flutter test test/calculators/crash_detector_test.dart`
- [ ] Deploy Cloud Functions: `firebase deploy --only functions`
- [ ] Set Firestore TTL policy for liveSessions (24h)
- [ ] Configure Twilio SMS credentials (production)
- [ ] Configure SendGrid email credentials (production)
- [ ] Update Firebase config in live-viewer.html
- [ ] Test crash detection with fixtures
- [ ] Test emergency contact notification flow
- [ ] Test live session sharing in real ride
- [ ] Verify token expiry after 24h

## Support & Debugging

**Check crash detection:**
```dart
final detector = EventDetector();
final alert = detector.detect(accel: 10.0, jerk: 12.0, speedMs: 0.5);
print(alert); // RideAlert.crash
```

**Check live session token:**
```
Open browser console on live-viewer.html
Check Firestore: /liveSessions/{token}
Verify lastLat, lastLng update every 10s
```

**Check crash notification:**
```
Firestore: /crashNotifications/{documentId}
Check status progression: pending → contacted → escalated
```

**Simulate crash for testing:**
1. Start ride
2. Hold phone horizontally, tap desk sharply (accel spike)
3. Quickly rotate to flat and hold still (speed→0)
4. UI should show "Crash Detected" countdown
5. Tap "I'm OK" or wait 60s for auto-escalation
