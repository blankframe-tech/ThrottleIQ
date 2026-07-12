# ThrottleIQ


# ThrottleIQ

**Ride smarter. Track deeper. Remember forever.**

ThrottleIQ is a motorcycle-first tracking, intelligence, and memory platform. It captures precise ride data (GPS, acceleration, jerk), provides maintenance reminders, detects aggressive riding patterns, and builds a lasting emotional value through ride history – all in a clean, performance-oriented UI.

> Not just another tracking app – a smart riding companion + machine memory system.

---

## 🎯 Key Features

### 🏍️ Multi-Bike Garage
- Add unlimited bikes (brand, model, CC, image)
- Track per-bike stats (total distance, ride count, last ride)

### 🎥 Ride Recording
- Press & hold to start/stop recording
- Full-screen map with live speed and telemetry
- Captures: GPS position, speed, acceleration, **jerk** (rate of change of acceleration)

### 📊 Ride Analytics
- Ride summary: distance, avg/max speed, duration
- Event counts: hard brakes, rapid accelerations, high-jerk events
- Map replay (planned)

### 🚨 Real-Time Alerts (V2)
- Overspeed, harsh braking, fatigue alerts
- Subtle flash + haptic feedback

### 🔧 Maintenance System
- Distance- and time-based reminders
- Example: oil change every 1000–1500 km, air filter in dusty conditions
- Cost tracking and maintenance log

### 🤖 AI Chatbot (V2)
- Maintenance advice, ride explanation, general bike Q&A
- Context-aware using ride data

### 👥 Lightweight Social
- Share ride summaries
- Follow users, like/comment (optional)

---

## 🧱 Tech Stack

| Layer       | Technology                                      |
|-------------|-------------------------------------------------|
| Frontend    | Flutter (single codebase for Android & iOS)    |
| Backend     | Node.js / Django (REST API)                     |
| Database    | PostgreSQL                                      |
| Realtime    | Firebase Auth + Push Notifications              |
| Maps        | Google Maps API                                 |
| Sensors     | GPS, Accelerometer, Gyroscope                   |

---

## 📐 Key Calculations

- **Speed** – from GPS
- **Acceleration** – `a = (v₂ - v₁) / (t₂ - t₁)`
- **Jerk** – `j = (a₂ - a₁) / (t₂ - t₁)` (detects sudden throttle/brake changes)

**Event thresholds** (configurable):
- Hard braking: `a < -4 m/s²`
- Rapid acceleration: `a > +4 m/s²`
- High jerk: exceeds defined threshold

---

## 🎨 UI Design System

- **Theme**: Dark Blue Performance UI
- **Colors**: `#0B0D10` (bg), `#3B82F6` (primary), `#FF6A00` (accent alerts)
- **Typography**: Inter, large numeric displays for speed/distance
- **Principles**: Dashboard-style, rounded corners (12–16px), high contrast, one-thumb usability

---

## 📱 Navigation (Bottom Tabs)

1. Social
2. AI Chatbot (V2)
3. **Record** (default open)
4. Maintenance
5. Garage/Profile

---

## 🗄️ Data Model (Simplified)

```sql
User(id, name, email)
Bike(id, user_id, brand, model, cc, image_url)
Ride(id, user_id, bike_id, start_time, end_time, distance, avg_speed, max_speed)
RidePoint(ride_id, timestamp, lat, lng, speed, acceleration, jerk)
Maintenance(bike_id, type, date, km, cost)
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (≥3.0)
- Node.js (≥18) or Python (≥3.10) + Django
- PostgreSQL
- Google Maps API key
- Firebase project (Auth, Push Notifications)

### Installation

1. **Clone the repo**
   ```bash
   git clone https://github.com/yourusername/ThrottleIQ.git
   cd ThrottleIQ
   ```

2. **Backend setup (Node.js example)**
   ```bash
   cd backend
   npm install
   cp .env.example .env   # add DB, Firebase, Maps keys
   npx prisma migrate dev
   npm start
   ```

3. **Flutter app**
   ```bash
   cd app
   flutter pub get
   flutter run --dart-define=MAPS_API_KEY=your_key
   ```

> Detailed setup in `/docs/setup.md`

---

## 🧪 Roadmap

| Version | Focus                          |
|---------|--------------------------------|
| V1 (MVP)| Ride tracking, multi-bike, maintenance, summary |
| V2      | Real-time alerts, chatbot, shareable cards |
| V3      | Social features, advanced insights |

---

## ✅ Success Metrics (Target)

- Daily Active Users (DAU)
- Rides per user per week
- 7-day & 30-day retention

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open a Pull Request

---

## 📄 License

[MIT](LICENSE) © ThrottleIQ Contributors

---

## 🙏 Acknowledgments

- Open-source Flutter & Node.js communities
- Inspired by real-world motorcycle maintenance gaps and riding analytics needs

---

**Made for riders, by riders.**

---

This README is ready to copy-paste into your repository. Replace `yourusername` with your actual GitHub username and adjust any backend specifics (Node vs Django) as needed.
