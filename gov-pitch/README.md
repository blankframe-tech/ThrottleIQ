# 🇧🇩 ThrottleIQ — iDEA Grant Application & Pitch Suite
**Innovation Design and Entrepreneurship Academy (iDEA)**  
*ICT Division, Ministry of Posts, Telecommunications and Information Technology, Government of Bangladesh*

Official Portal: [idea.gov.bd](https://idea.gov.bd/p/10/how-to-apply)  
Target Grant: **Pre-Seed Grant (BDT 10,00,000 / 10 Lakh)**  
Project Name: **ThrottleIQ**  
Organization: **Blankframe Technologies** (`com.bft.throttleiq`)  
Current Stage: Pre-Launch Production Beta (`1.0.0-beta.2.2+7`), 862 automated tests passing, Google Play Console Internal Track Live.

---

## 📁 Directory Structure

This directory contains the full grant application package prepared in strict accordance with the **iDEA Project How to Apply Guidelines**:

| File | Description |
| :--- | :--- |
| **[`Part-1-Pitch-Deck.md`](Part-1-Pitch-Deck.md)** | Complete 9-slide PowerPoint deck content, formatting guidance, diagrams, and speaker notes. |
| **[`Part-2-Video-Pitch-Script.md`](Part-2-Video-Pitch-Script.md)** | Word-for-word, 5-minute timed video script (Business Plan 3m, Architecture 1m, Team 1m) with visual/audio cues. |
| **[`Part-3-iDEA-Defense-and-FAQ.md`](Part-3-iDEA-Defense-and-FAQ.md)** | Selection committee interview defense guide, addressing Bangladesh road dynamics, pothole filtering, monetization, and offline safety. |
| **[`FULL_SUBMISSION.md`](FULL_SUBMISSION.md)** | Unified, single-document compilation suitable for PDF export, print, or web submission. |

---

## 🎯 Executive Pitch Summary

### The National Crisis
- Over **4.5 million registered motorcycles** operate in Bangladesh (growing by 500,000+ per year).
- Two-wheelers account for over **40% of all road crash fatalities**.
- Solo riders who crash on highways or isolated rural corridors often remain unwitnessed and unassisted during the critical "Golden Hour."
- Motorcycle upkeep is tracked by guesswork or memory, resulting in premature mechanical failure, fuel inefficiency, and severe resale value loss.

### The Solution: ThrottleIQ
- **Zero-Hardware Black Box:** Uses standard smartphone sensors (GPS + accelerometer + gyroscope) to create a motorcycle telematics computer.
- **Intelligent Signature Crash Detection:** Sensor-fusion algorithm (`EventDetector`) captures impact spikes + sudden deceleration curves, triggering a 60-second cancellable alarm to filter false positives (Dhaka potholes/speed breakers).
- **Automated Emergency Web Broadcast:** Unresponsive crashes immediately dispatch an unguessable 24-hour token link sharing real-time GPS, speed, and battery status with family—no app installation required for recipients.
- **100% Offline-First Architecture:** Local ACID SQLite database records 20+ telematics points/sec with zero cellular connectivity, synchronizing asynchronously to Firebase Firestore upon reconnection.
- **Predictive Garage Maintenance:** Maintenance intervals (engine oil, drive chain, brake pads, tire wear) are tracked against actual kilometers ridden.
- **Localized Ecosystem:** Dual English and Bangla interface with a crowdsourced, verified directory of local repair garages, fuel stations, and spare parts shops.

---

## 💰 The Ask & Grant Allocation (BDT 10,00,000)

| Priority Area | Allocation (BDT) | % | Deliverable |
| :--- | :--- | :--- | :--- |
| **Automated Emergency Telecom Gateway** | BDT 3,50,000 | 35% | Integrate local SMS/voice telecom APIs (SSL Wireless/Infobip) for immediate carrier-level emergency dispatch. |
| **Crash Sensor Track Calibration & Dummies** | BDT 2,50,000 | 25% | Controlled physical track testing with crash rigs to certify zero false positives across Bangladeshi road conditions. |
| **Public Store Releases & Cloud Infra** | BDT 2,00,000 | 20% | Production rollout on Google Play Store and Apple App Store, Firebase Blaze cloud scaling. |
| **Garage Partner Onboarding & Community** | BDT 1,50,000 | 15% | Onboarding 500+ local mechanics with verified SafeSpot listings and community outreach across motorcycle clubs. |
| **Regulatory, Licensing & IP** | BDT 50,000 | 5% | Trade license, software copyright/patent applications, and BRTA road safety alignment. |

---

## 🚀 How to Use These Materials

1. **For the Slide Deck:** Copy the content from [`Part-1-Pitch-Deck.md`](Part-1-Pitch-Deck.md) into PowerPoint or Google Slides following the design specifications.
2. **For the Video Pitch:** Use the teleprompter-ready timestamps in [`Part-2-Video-Pitch-Script.md`](Part-2-Video-Pitch-Script.md) to record the 5-minute video in MP4/AVI format.
3. **For the Interview:** Review [`Part-3-iDEA-Defense-and-FAQ.md`](Part-3-iDEA-Defense-and-FAQ.md) with the team before facing the iDEA evaluation committee.
