# ThrottleIQ V1.0 Beta Release Notes

**Release Date:** May 14, 2026  
**Platform:** Android 8.0+  
**Build:** Release APK (production-ready)

---

## 🎉 What's New in This Build

### 🔧 Critical Fixes
- ✅ Fixed sensor event processing crash (removed invalid `mounted` checks from StateNotifier)
- ✅ Fixed database schema migrations with proper version management
- ✅ Improved state management stability in ride recording

### 📱 Screen Keep-Alive Feature
- **New:** Wakelock integration — Screen stays on during active rides
- Screen automatically turns off when ride is paused or completed
- Prevents accidental timeout while navigating or watching speed
- Reduces battery drain compared to manual screen management

### 🗺️ Idle Period Tracking (Database Ready)
- **Infrastructure:** Added `period_type` column to ride_points table
- Ready for implementation: Will categorize stopped periods as idle/traffic/break
- Enables future analytics on rider behavior during stops
- Seamless migration for existing users

### 📊 Database Improvements
- Enhanced schema with version 2 (from version 1)
- Automated migration system for future updates
- Proper foreign key constraints
- Optimized indexes for faster queries

---

## ✨ Existing Features (V1.0 MVP)

### Ride Recording
- Real-time GPS tracking with 5m distance filter
- Physics calculations: speed, acceleration, jerk
- Event detection: hard braking, rapid acceleration, high jerk
- Live alerts with haptic feedback
- Offline recording (data persists even if app crashes)
- Automatic ride resumption on app restart

### Garage & Bikes
- Add/edit/delete multiple bikes
- Store brand, model, year, CC, custom image
- Track total distance and ride count per bike
- Select active bike for recording

### Maintenance
- Log services: oil change, air filter, chain lube, tire check, custom
- Automatic reminders based on distance/time
- Cost tracking for budgeting
- Smart reminder status: OK / Due Soon / Overdue
- Detailed notes for each service

### Analytics
- Ride summary with map, distance, duration, speeds
- Event metrics: hard brakes, rapid acceleration counts
- Bike statistics dashboard
- Per-bike total distance and ride count

### User Experience
- Dark theme dashboard optimized for sunlight
- Intuitive bottom navigation (5 tabs)
- Firebase email/password authentication
- Offline-first architecture (SQLite)

---

## 🐛 Known Limitations

### Current
- **No Cloud Sync** — All data stored locally only (feature for V1.1)
- **Social Features** — Database ready but backend not implemented yet
- **Profile Screen** — Coming in V1.1 with emergency contact & friends
- **iOS** — Android-only for beta (iOS coming V1.1)
- **Chat Bot** — UI shell only, no AI integration yet

### Performance
- Large rides (>500 points) may cause minor UI lag
- Map rendering not optimized for very long routes yet

---

## 📋 Setup Instructions for Beta Testers

### Requirements
- Android 8.0 or higher
- ~60MB storage space
- Google Play Services installed
- Location permissions (required for GPS)

### Installation
1. Download the APK: `throttleiq/build/app/outputs/flutter-apk/app-release.apk`
2. Enable "Unknown Sources" in Settings > Security (Android)
3. Install APK file
4. Launch ThrottleIQ app

### First Time Setup
1. Register with email/password
2. Enter display name
3. Add your first bike (brand, model, year, CC)
4. Grant location permissions when prompted
5. Start recording a test ride

### Recording a Test Ride
1. Open "Record" tab (bottom center)
2. Tap "Start Ride" or press & hold button
3. Button turns green — recording active
4. Speed and sensor data update in real-time
5. Tap to pause or end ride
6. Review ride summary with map

---

## 🧪 Testing Checklist

### Critical Paths
- [ ] App launches successfully and splash screen completes
- [ ] Can register new account and log in
- [ ] Can add a bike to garage
- [ ] Can start and complete a ride (5+ min)
- [ ] Ride data saves correctly to history
- [ ] App doesn't crash during ride recording
- [ ] Screen stays on during active ride (wakelock working)
- [ ] Events detected: hard braking, rapid acceleration

### Features to Test
- [ ] Maintenance reminders show correct status (OK, Due Soon, Overdue)
- [ ] Log a maintenance service
- [ ] Switch between bikes and verify active bike is selected
- [ ] Location permission handling
- [ ] Offline operation (airplane mode after ride starts)

### Edge Cases
- [ ] Long ride (30+ minutes) — no lag
- [ ] Pause and resume ride — duration tracks correctly
- [ ] Multiple bikes with different stats
- [ ] App backgrounding during active ride (should continue recording)
- [ ] Force close app and reopen — last ride recovers

---

## 📝 Feedback & Reporting Bugs

### How to Report Issues
1. **In-app Crash** — Note the screen/action when it occurred
2. **Data Issue** — Screenshot the anomaly
3. **Feature Request** — Describe what you'd like to see
4. **Performance** — Mention device model and data size

### Report via Email
Send feedback to: `devops@inovacetech.com`

**Include in Report:**
- Device model and Android version
- Exact steps to reproduce (if bug)
- Screenshot or log message
- Expected vs. actual behavior

---

## 🚀 What's Coming in V1.1 (June-September 2026)

### High Priority
- **Idle Period Analytics** — Categorize stop times as idle/traffic/break
- **Interactive Maps** — Zoom, pan, route replay on ride summary
- **Export Rides** — Download as GPX or CSV
- **iOS Support** — Full iPhone and iPad support
- **Performance Fixes** — Battery optimization, memory efficiency

### User Features
- **Profile Screen** — Emergency contact, blood group, saved routes
- **Friend System** — Add friends via QR code, share rides
- **Ride History Browser** — Filter and search past rides
- **Push Notifications** — Maintenance reminders and alerts

---

## 🔐 Data & Privacy

### Data Storage
- All ride data, bike info, and maintenance logs stored locally on device
- No data sent to cloud servers (by design for beta)
- Database backed up in app's private storage

### Permissions Required
- **Location** — GPS data for ride tracking (required)
- **Sensors** — Accelerometer for event detection (required)
- **Photos** — Bike image upload (optional)

### Privacy
- No telemetry or analytics in beta version
- No user profiling or data sharing
- User data deletion available on request

---

## 📞 Support

For issues, crashes, or feature requests during beta:

**Email:** devops@inovacetech.com  
**Response Time:** 24-48 hours  
**Feedback Used For:** Prioritizing V1.1 features

---

## 🎯 Version Information

| Version | Status | Date | Features |
|---------|--------|------|----------|
| V1.0 | **BETA** | May 2026 | Ride tracking, garage, maintenance |
| V1.1 | In Development | Jun 2026 | iOS, profiles, friends, analytics |
| V2.0 | Planned | Dec 2026 | Social, AI chatbot, advanced features |

---

## 🏍️ Ride Smarter. Track Deeper. Remember Forever.

Thank you for testing ThrottleIQ! Your feedback shapes the future of this platform.

**Happy riding!**
