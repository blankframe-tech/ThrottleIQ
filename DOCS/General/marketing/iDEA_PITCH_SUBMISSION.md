# ThrottleIQ — Official iDEA Grant Application & Pitch Submission
**ICT Division, Government of Bangladesh | Innovation Design and Entrepreneurship Academy (iDEA)**

*Project:* **ThrottleIQ**  
*Company:* **Blankframe Technologies** (`com.bft.throttleiq`)  
*Tagline:* **Machine Memory for Motorcycles** (*রাইডের ডিজিটাল ব্ল্যাকবক্স ও সুরক্ষাকবচ*)  
*Stage:* Pre-Launch Working Beta (`1.0.0-beta.2.2+7`), Tested & Internal Track Deployed  
*Target Grant:* **Pre-Seed Grant (BDT 10,00,000 / 10 Lakh)**  

---

# Table of Contents
1. [Submission Overview & Executive Summary](#submission-overview--executive-summary)
2. [Part 1: Pitch Deck (Slide-by-Slide PowerPoint Structure)](#part-1-pitch-deck-slide-by-slide-powerpoint-structure)
   - [Slide 1: Introduction – Company](#slide-1-introduction--company)
   - [Slide 2: Problem & Solution Scenario](#slide-2-problem--solution-scenario)
   - [Slide 3: Market Size & Possibilities (TAM / SAM / SOM)](#slide-3-market-size--possibilities-tam--sam--som)
   - [Slide 4: Competitive Advantage & Unique Features](#slide-4-competitive-advantage--unique-features)
   - [Slide 5: What is Your Need? (Funding, Mentoring, Resources)](#slide-5-what-is-your-need-funding-mentoring-resources)
   - [Slide 6: Technology Strategy & Architecture](#slide-6-technology-strategy--architecture)
   - [Slide 7: Business Strategy & Go-To-Market (GTM)](#slide-7-business-strategy--go-to-market-gtm)
   - [Slide 8: Financial Strategy, Pricing & Revenue Projections](#slide-8-financial-strategy-pricing--revenue-projections)
   - [Slide 9: Management Team & Execution Track Record](#slide-9-management-team--execution-track-record)
3. [Part 2: 5-Minute Video Pitch Script (Timed with Cues)](#part-2-5-minute-video-pitch-script-timed-with-cues)
   - [Section 1: Business Plan (0:00 – 3:00)](#section-1-business-plan-000--300)
   - [Section 2: Technical Architecture (3:00 – 4:00)](#section-2-technical-architecture-300--400)
   - [Section 3: Management Team (4:00 – 5:00)](#section-3-management-team-400--500)
4. [Part 3: iDEA Selection Committee Defense & FAQ Cheat Sheet](#part-3-idea-selection-committee-defense--faq-cheat-sheet)

---

# Submission Overview & Executive Summary

In Bangladesh, over **4.5 million motorcycles** are registered with the BRTA, with more than **500,000 new two-wheelers** added every year. Motorcycles are the backbone of rapid urban transport and last-mile commerce. Yet, two-wheelers account for over **40% of all road crash fatalities in Bangladesh**. When an accident occurs on a national highway or isolated rural corridor, emergency assistance is delayed because no one knows a crash has occurred until it is too late. Furthermore, riders have no digital tool to monitor vehicle health, tracking maintenance with arbitrary guesswork that leads to mechanical failures and costly breakdowns.

**ThrottleIQ** transforms any standard Android or iOS smartphone into an intelligent, hardware-less motorcycle telematics "black box." Using proprietary multi-sensor fusion algorithms (accelerometer, gyroscope, GPS velocity derivatives), ThrottleIQ detects crash impact signatures, initiates a 60-second cancellable audio-visual countdown to filter out potholes and false alarms, and automatically shares a live, encrypted emergency location link with designated loved ones. Crucially, ThrottleIQ is built **100% offline-first**: all ride telematics, telemetry curves, and maintenance triggers operate reliably even in complete cellular dead zones, synchronizing seamlessly with cloud servers when network connectivity resumes.

With a fully functioning app (`862 unit & domain tests, 73 Firestore security tests`), verified Android APK, and Play Console deployment, ThrottleIQ is seeking a **10 Lakh BDT Pre-Seed Grant** from the iDEA Project to scale its automated SMS/voice emergency dispatch infrastructure, complete nationwide crash-calibration testing, and onboard 50,000 riders in Bangladesh.

---

# Part 1: Pitch Deck (Slide-by-Slide PowerPoint Structure)

> **Design Tip for Slides:** Use ThrottleIQ's dark mode visual language (Deep Carbon `#121212`, Safety Amber `#FF9800` / Electric Cyan `#00E5FF`, Crisp White `#FFFFFF`). Keep fonts bold and high-contrast (e.g., Space Grotesk / Inter). Avoid cluttered text; utilize clean metric cards and system diagrams.

---

### Slide 1: Introduction – Company

- **Visual Header:** ThrottleIQ Speedometer Arc Emblem + Wordmark
- **Tagline:** Machine Memory for Motorcycles (*রাইডের ডিজিটাল ব্ল্যাকবক্স ও সুরক্ষাকবচ*)
- **Company Name:** Blankframe Technologies (`com.bft.throttleiq`)
- **Key Snapshot:**
  - **What we do:** AI-powered smartphone telematics, crash detection, and predictive maintenance for two-wheelers.
  - **Status:** Fully functional working beta (`1.0.0-beta.2.2+7`), 862+ automated tests green, signed APK & Play Console internal track.
  - **Mission:** Zero unwitnessed motorcycle crashes and data-driven vehicle longevity for every rider in Bangladesh.
- **Presenter Names:** Founder & Lead Architect / Core Management Team
- **Contact:** info@throttleiq.com | Dhaka, Bangladesh | https://github.com/blankframe-tech/ThrottleIQ

---

### Slide 2: Problem & Solution Scenario

#### The Problem (Current Bangladesh Reality)
1. **The Unseen Highway Tragedy:** 
   - Over 40% of road accident fatalities in Bangladesh involve two-wheelers. On long highway stretches (Dhaka–Chattogram, Bangabandhu Expressway) or rural bypasses, solo riders who crash remain unassisted for the critical "Golden Hour."
2. **Zero Telematics for Two-Wheelers:**
   - Unlike modern passenger cars equipped with OBD-II computers, 99% of motorcycles in Bangladesh have zero digital diagnostics or data memory.
3. **Guesswork Maintenance & High Depreciation:**
   - Over 80% of riders track engine oil, chain lubrication, and brake wear by guesswork, leading to roadside breakdowns, fuel wastage, and lost resale value in a high-turnover used market.
4. **Existing Apps Fail Local Needs:**
   - Foreign apps (Strava, Rever, Calimoto) are built for cyclists or luxury Western sports bikes; they fail in mobile dead zones, require costly \$10+/month subscriptions, lack local repair garage directories, and have no Bangla support.

#### The Solution (ThrottleIQ)
- **Smartphone-Only Black Box:** Transforms the rider's phone into an onboard computer with zero extra hardware or wiring modifications required.
- **Real-Time Signature Crash Detection:** Sensor-fusion algorithm (impact acceleration spike + rapid velocity drop) initiates a 60-second audio-visual alarm. If uncancelled, it broadcasts an unguessable emergency token link displaying live GPS location, battery percentage, and speed.
- **True Offline-First Architecture:** 100% functional without mobile data. Telemetry is saved locally in an ACID SQLite database and syncs when back online.
- **Distance-Based Garage Memory:** Service intervals for engine oil, drive chain, air filter, and tires are automatically tracked against actual kilometers ridden.
- **Localized Rider Ecosystem:** Built-in community directory of verified fuel stations, repair mechanics, and spare parts shops, with full dual English/Bangla language support.

---

### Slide 3: Market Size & Possibilities (TAM / SAM / SOM)

#### Bangladesh Market Opportunity
- **Total Addressable Market (TAM):**
  - **4.5 Million+** Registered Motorcycles in Bangladesh (BRTA official records).
  - Annual two-wheeler economic expenditure (fuel, consumables, maintenance, insurance): **BDT 1,500+ Crore (\$130M+ USD)**.
- **Serviceable Addressable Market (SAM):**
  - **1.2 Million** Smartphone-equipped urban commuters and gig delivery riders (Dhaka, Chattogram, Sylhet, Rajshahi).
  - Includes ~250,000 active delivery riders working with ride-sharing and logistics fleets (Pathao, Foodpanda, Shohoz, Steadfast, RedX).
- **Serviceable Obtainable Market (SOM - 18 to 24 Months):**
  - **50,000 Active Monthly Riders** targeted through motorcycle touring clubs, brand enthusiast communities, and delivery fleet partnerships.
  - Projecting BDT 3.5 Crore annual recurring revenue across consumer subscriptions and B2B fleet safety dashboards.

#### Market Growth Drivers
- Rapid adoption of affordable 4G/5G smartphones across Bangladesh.
- Government push for **Smart Bangladesh 2041** and national road safety digitisation.
- Boom in two-wheeler logistics and commuter reliance amidst urban traffic congestion.

---

### Slide 4: Competitive Advantage & Unique Features

| Evaluation Criteria | Global Fitness Apps (Strava, Komoot) | Western Moto Apps (Rever, Detecht) | Hardware OBD Trackers | **ThrottleIQ (Blankframe Tech)** |
| :--- | :--- | :--- | :--- | :--- |
| **Crash Detection** | ❌ None (Bicycle/Run focus) | ⚠️ Requires active 4G data | ⚠️ Basic tilt sensor only | ✅ **Impact + Speed-Drop Signature (Filters Potholes)** |
| **Emergency Live Link** | ⚠️ Paid paywall | ⚠️ Account required by recipient | ❌ SMS only, no map | ✅ **Token-Based Link (Openable on any browser)** |
| **Network Resilience** | ❌ Fails on weak signal | ❌ Dropped rides | ⚠️ Dependent on 2G SIM | ✅ **100% Offline-First SQLite Architecture** |
| **Maintenance Tracking** | ❌ None | ❌ Manual date entry | ❌ None | ✅ **Automatic km-Based Service Triggers** |
| **Hardware Requirement** | ✅ None | ✅ None | ❌ Costs BDT 3,500 - 8,000 + SIM | ✅ **Zero Hardware (Uses Phone Sensors)** |
| **Localization & POI** | ❌ None | ❌ None | ❌ None | ✅ **Bangla Language & Local Garage Directory** |
| **Price Point** | \$80 / year (BDT 9,500) | \$60 / year (BDT 7,200) | BDT 500/month recharge | **Freemium + BDT 99/mo (Pro)** |

#### Key Moats:
1. **Proprietary Sensor Tuning:** Calibrated specifically against Bangladesh road conditions (filtering sudden bumps, speed breakers, and Dhaka traffic stops).
2. **Zero Hardware Barrier:** Zero installation fee makes adoption instantaneous for everyday 100cc–160cc commuter bikes (Yamaha, Bajaj, TVS, Hero, Runner).
3. **Verified Local Utility:** POI database crowdsourced and verified for Bangladeshi mechanics and fuel pumps.

---

### Slide 5: What is Your Need? (Funding, Mentoring, Resources)

#### Financial Ask: BDT 10,00,000 (10 Lakh) Pre-Seed Grant (iDEA)

| Allocation Area | Amount (BDT) | Percentage | Strategic Deliverable |
| :--- | :--- | :--- | :--- |
| **Automated Emergency Dispatch Infrastructure** | **BDT 3,50,000** | 35% | Integrate local SMS/voice telecom gateways (SSL Wireless/Infobip) to enable automatic phone call and SMS alerts when crash countdown expires. |
| **Crash Sensor Calibration & Field Testing** | **BDT 2,50,000** | 25% | Controlled track crash testing with crash dummies and telemetry rigs to eliminate false positives and certify crash-signature accuracy. |
| **App Store Launches & Cloud Infrastructure** | **BDT 2,00,000** | 20% | Production Google Play Console & Apple App Store public releases, Firebase Blaze scalable serverless capacity. |
| **Community Seeding & Garage Network Onboarding** | **BDT 1,50,000** | 15% | Onboarding 500+ local motorcycle mechanics/garages in Dhaka & Chattogram with verified ThrottleIQ SafeSpot badges. |
| **Regulatory & IP Protection** | **BDT 50,000** | 5% | Trade licensing, data protection compliance, and intellectual property / trademark filings. |
| **Total** | **BDT 10,00,000** | **100%** | **Milestone-driven execution across 12 months** |

#### Mentoring & Operational Needs from iDEA:
- **BRTA & Highway Police Advisory:** Integration guidelines with national emergency services (`999`) and road transport authorities.
- **Co-working Space & Lab Support:** Access to iDEA incubation facilities at ICT Tower, Agargaon for testing and hardware rigs.
- **Corporate Partnerships:** Introductions to courier/logistics enterprises (e.g., e-Courier, Pathao, Foodpanda) for B2B fleet safety pilot projects.

---

### Slide 6: Technology Strategy & Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           THROTTLEIQ CLIENT                              │
│  Flutter (Dart) Mobile App • Cross-Platform (Android & iOS)              │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                    SENSOR FUSION ENGINE (20 Hz)                    │  │
│  │  • 3-Axis Accelerometer + Gyroscope + GPS Delta Vector            │  │
│  │  • Jerk & Rapid Deceleration Profiler                              │  │
│  │  • EventDetector & VehicleStateEstimator (Pothole Filtering)       │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                  OFFLINE-FIRST STORAGE LAYER                       │  │
│  │  • Local SQLite Engine (Single Source of Truth)                    │  │
│  │  • Transactional Outbox Pattern (Guaranteed Zero Data Loss)        │  │
│  │  • SafeQR Medical Card (Device-Encrypted Emergency Info)          │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     │ Async Sync (Resume / 5-min timer)
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         FIREBASE CLOUD BACKEND                           │
│  • Cloud Firestore: Encrypted Multi-Tenant Telemetry & User Profiles     │
│  • Cloud Functions (Node.js/TS): Crash Escalation & Tokenized Web Views │
│  • Geohash Spatial Engine: Efficient POI Queries for Fuel/Garages        │
│  • Firebase Crashlytics: Real-time Device Diagnostic & Quality Metrics    │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     │ Webhook Trigger
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                   EMERGENCY DISPATCH & TELECOM LAYER                     │
│  • Emergency Web Portal: Unguessable 24-hr Token Link (No login needed)  │
│  • National SMS / Voice Gateway: Multi-Contact Automated Broadcast       │
└──────────────────────────────────────────────────────────────────────────┘
```

- **Engineering Excellence:** 862 automated unit/domain tests covering motion calculators and DAO safety; 73 automated Firestore security rules.
- **Battery & Resource Optimization:** Adaptive foreground service sampling that dynamically throttles sensor polling when the vehicle is stationary, preserving all-day phone battery.

---

### Slide 7: Business Strategy & Go-To-Market (GTM)

#### Phase 1: Community Grassroots & Enthusiast Seeding (Months 1–4)
- **Moto Clubs & Brand Communities:** Direct seeding with Dhaka and regional touring clubs (Yamaha FZ/R15 Clubs, Honda Hornet BD, Bajaj Pulsar Owners, Royal Enfield Bangladesh).
- **Influencer Validation:** Collaboration with top Bangladeshi moto vloggers to demonstrate real offline tracking and crash-detection simulations on YouTube and Facebook Reels.
- **Bangla-First Campaign:** Street poster and social campaigns highlighting *"Works when your signal doesn't"* (*"সিগন্যাল না থাকলেও রেকর্ড হতে থাকে"*).

#### Phase 2: B2B Fleet Pilots & Commercial Logistics (Months 5–8)
- **Gig Worker Safety Program:** Pilot rollouts with courier and food delivery riders. Providing companies with a dashboard tracking fleet safety scores, excessive speeding, and automated crash alerts.
- **Value Proposition for Fleets:** Reduced delivery accidents, lower insurance liability, and automated preventive maintenance alerts for company bikes.

#### Phase 3: Garage & Ecosystem Monetization (Months 9–12+)
- **ThrottleIQ Verified Partner Garages:** Local repair shops receive free digital listing in the POI directory, displaying verified service ratings. Garages refer riders to ThrottleIQ to receive automatic service reminders.

---

### Slide 8: Financial Strategy, Pricing & Revenue Projections

#### Revenue Model
1. **B2C Freemium Core (Free Forever):**
   - Unlimited offline ride recording, ride summary analytics, local maintenance alerts, cancellable crash countdown, tokenized live share link.
2. **ThrottleIQ Pro (BDT 99 / month or BDT 899 / year):**
   - Automated multi-contact SMS and automated voice call crash escalation.
   - Cloud backup of lifetime riding telemetry, GPX/JSON route export.
   - Advanced vehicle dynamics: lean-angle analysis, acceleration curves, and monthly riding performance certificates.
3. **B2B Fleet Safety SaaS (BDT 150 / bike / month):**
   - Web dispatch dashboard for delivery companies, driver safety league tables, automated maintenance audit trail.
4. **Verified Marketplace Lead Fees (BDT 300 – 500 / month / garage):**
   - Featured listings for aftermarket parts retailers, authorized bike service centers, and tire shops.

#### 3-Year Financial Forecast (in BDT)

| Metric | Year 1 (Launch & Seeding) | Year 2 (Growth & Monetization) | Year 3 (Scale & Enterprise) |
| :--- | :--- | :--- | :--- |
| **Total Registered Users** | 50,000 | 250,000 | 750,000 |
| **Pro Subscribers (B2C @ ~4%)** | 2,000 | 12,500 | 45,000 |
| **B2B Tracked Fleet Bikes** | 500 | 3,000 | 12,000 |
| **B2C Subscription Revenue** | BDT 18,00,000 | BDT 1,12,50,000 | BDT 4,05,00,000 |
| **B2B Fleet SaaS Revenue** | BDT 9,00,000 | BDT 54,00,000 | BDT 2,16,00,000 |
| **Directory & Partner Revenue** | BDT 1,50,000 | BDT 9,50,000 | BDT 35,00,000 |
| **Total Gross Revenue** | **BDT 28,50,000** | **BDT 1,76,00,000** | **BDT 6,56,00,000** |
| **Operating Expenses (Hosting, SMS, Ops)**| BDT 21,00,000 | BDT 85,00,000 | BDT 2,40,00,000 |
| **Net Profit / (Loss)** | **+ BDT 7,50,000** | **+ BDT 91,00,000** | **+ BDT 4,16,00,000** |

*Note: High gross margins (>75%) driven by lightweight serverless architecture and smartphone-native edge computation.*

---

### Slide 9: Management Team & Execution Track Record

- **Founder & Lead Software Architect (Blankframe Technologies):**
  - Full-stack mobile and cloud systems engineer. Architected the entire 862-test ThrottleIQ offline-first engine, motion filtering calculators, and transactional database layer.
- **Embedded & Sensor Systems Lead:**
  - Background in robotics and IoT signal processing. Manages 3-axis accelerometer calibration, jerk profiling, and dynamic motion models.
- **Growth, Community & Operations Lead:**
  - Active participant in Bangladesh touring rider networks. Manages relations across regional moto clubs, verified garage onboarding, and social channels.
- **Advisory Panel:**
  - Senior Automotive Safety Consultant: Expertise in road safety protocols and vehicle crash biomechanics.
  - Legal & Governance Advisor: Specializing in ICT compliance, digital privacy, and commercial contracts.

**Execution Track Record:**
- Shipped `1.0.0-beta.2.2+7` with zero external funding.
- 862 automated unit tests + 73 security-rule tests passing green.
- Internal test release live on Google Play Console.

---

# Part 2: 5-Minute Video Pitch Script (Timed with Cues)

> **Format:** 1080p MP4/AVI video. High quality audio.  
> **Rule:** Time limit is **strictly 5 minutes (300 seconds)**.  
> **Dynamic Team Setup:** Three presenters (Founder/CEO, Tech Lead, Growth Lead) sitting or standing in a clean, tech-focused environment with a real motorcycle and phone mount in the background. Do not read from slides! Speak directly into the camera with passion and clarity.

---

### Timing Breakdown
- **0:00 – 3:00 (3 Min):** Business Plan
- **3:00 – 4:00 (1 Min):** Technical Architecture
- **4:00 – 5:00 (1 Min):** Management Team & Ask

---

## Section 1: Business Plan (0:00 – 3:00)

#### [0:00 – 0:40] Problem Statement & The Real-World Crisis
**Speaker 1 (Founder/CEO):**
*(Looking directly into the camera with earnest urgency)*
> "Assalamu Alaikum. Every single day in Bangladesh, millions of people get on a motorcycle to earn their livelihood, deliver our essentials, or commute through intense traffic. Over 4.5 million bikes are on our roads today.
>
> But there is a silent, heartbreaking crisis. Two-wheelers account for more than 40% of all fatal road accidents in our country. When a rider goes down on a national highway like Dhaka-Mawa or an isolated rural road late at night, no one knows. Minutes turn into hours, and lives are lost simply because help arrived too late.
>
> At the same time, riders have zero data on their bikes. Maintenance is managed through fading memory or notebooks, leading to sudden mechanical breakdowns and costly repairs."

*(Visual Cue: Cut to 5 seconds of footage showing highway riding, followed by a phone mounted on a motorcycle handlebar running ThrottleIQ).*

---

#### [0:40 – 1:15] The Product & Solution
**Speaker 1 (Founder/CEO):**
> "We built **ThrottleIQ** to solve this. ThrottleIQ turns any standard smartphone into an intelligent black box and lifesaver for motorcycles—with zero expensive hardware needed.
>
> First: **Intelligent Crash Detection**. ThrottleIQ continuously monitors motion dynamics. When it senses a crash impact followed by an instant drop in speed, it sounds a loud 60-second countdown. If the rider is unharmed or it was just a dropped phone, they tap to cancel. If they are unresponsive, ThrottleIQ immediately broadcasts an emergency link with their exact live GPS location, speed, and battery level to their family.
>
> Second: **Machine Memory**. ThrottleIQ automatically tracks engine oil, chain slack, brake pads, and tires against actual kilometers ridden—alerting the rider exactly when maintenance is due."

---

#### [1:15 – 1:50] Target Market & Market Size
**Speaker 3 (Growth Lead):**
*(Step forward, holding a tablet displaying market breakdown)*
> "Who are we building this for? In Bangladesh alone, our Total Addressable Market is over 4.5 million registered motorcycles—an ecosystem exceeding 1,500 Crore Taka annually in maintenance, fuel, and aftermarket services.
>
> Our immediate target—our SAM—is the 1.2 million smartphone-connected urban commuters and 250,000 gig delivery riders working for platforms like Pathao and Foodpanda in Dhaka, Chattogram, and Sylhet.
>
> Within the next 18 months, our Serviceable Obtainable Market is **50,000 active riders**, giving us a solid, profitable beachhead in Bangladesh before expanding across South Asia."

---

#### [1:50 – 2:25] Business Model & Revenue Streams
**Speaker 3 (Growth Lead):**
> "Our business model is built around accessibility and scalable high-margin software:
>
> 1. **B2C Freemium Core:** Essential offline ride recording, trip analytics, and local emergency links are completely free forever.
> 2. **ThrottleIQ Pro:** At just 99 Taka a month or 899 Taka a year—the cost of a cup of tea a week—riders get automated SMS and emergency voice-call dispatch, lifetime cloud backups, and advanced lean-angle telemetry.
> 3. **B2B Fleet Safety Dashboard:** Courier and delivery logistics companies pay 150 Taka per bike monthly for fleet safety monitoring, driver risk scores, and automated fleet maintenance scheduling.
> 4. **Verified Garage Network:** Local mechanics pay a small monthly listing fee to be featured as certified service hubs in our rider directory."

---

#### [2:25 – 3:00] Traction, Competition & The Ask
**Speaker 1 (Founder/CEO):**
> "Where do we stand today? We aren't an idea on a napkin. ThrottleIQ is a fully built, battle-tested product. We have tagged version `1.0.0-beta.2.2`, backed by 862 automated tests, and our build is currently in internal testing on the Google Play Console!
>
> While foreign apps like Strava or Rever exist, they charge 10 dollars a month, fail completely in network dead zones, and don't care about Bangladeshi road conditions. ThrottleIQ is 100% offline-first, fully bilingual in Bangla, and requires zero external hardware.
>
> To take this to every rider in Bangladesh, we are seeking the **10 Lakh BDT Pre-Seed Grant** from the iDEA Project. This funding will scale our automated SMS telecom gateway for crash alerts, support rigorous track-calibration testing, and fund our public launch on the Google Play Store and App Store."

---

## Section 2: Technical Architecture (3:00 – 4:00)

**Speaker 2 (Technical Lead):**
*(Standing beside an architecture diagram screen, holding an Android phone running live telemetry)*
> "Let's look under the hood. Two-wheeler telematics on a smartphone is an extreme engineering challenge. You face engine vibration, phone orientation shifts, and severe cellular dead zones.
>
> We engineered ThrottleIQ on a resilient, three-layer architecture:
>
> 1. **Edge Sensor Fusion Engine:** Written in Flutter and Dart, our engine samples 3-axis accelerometer and GPS velocity derivatives 20 times every second. Our adaptive `EventDetector` uses jerk profiling and deceleration curves to distinguish a genuine highway crash from a pothole, speed bump, or sudden brake.
>
> 2. **True Offline-First Storage:** Most apps fail when connectivity drops. ThrottleIQ uses a local SQLite database with an ACID-compliant transactional outbox pattern. Even if you ride through 100 kilometers of cellular blackout, zero data is lost. The moment the phone detects signal, it syncs incrementally to Cloud Firestore in the background.
>
> 3. **Serverless Escalation & Tokenized Web Access:** Our Firebase Cloud Functions generate unguessable, 24-hour emergency tokens. Anxious family members don't even need to download the app—they click a text link and immediately see their rider's live map, battery level, and nearest hospital.
>
> Every line of code is held to mission-critical standards: 862 automated domain tests and 73 security-rule tests running green on every build."

---

## Section 3: Management Team & Commitment (4:00 – 5:00)

**Speaker 1 (Founder/CEO):**
*(Whole team on screen, looking confident and united)*
> "Behind ThrottleIQ is a team with the technical depth and domain passion to execute:
>
> I am the Founder and Lead Systems Architect at Blankframe Technologies. I've engineered real-time distributed applications, mobile telemetry pipelines, and led ThrottleIQ from concept to over 800 passing tests and working production builds.
>
> Alongside me is our Embedded & Sensor Systems Lead, who brings specialized expertise in signal processing, accelerometer noise filtering, and vehicle dynamics.
>
> And our Growth Lead is deeply embedded in the Bangladeshi motorcycling community, with relationships across touring clubs, brand groups, and local garage networks in Dhaka and Chattogram.
>
> We are advised by senior automotive safety experts and cloud infrastructure veterans.
>
> Honorable judges of the iDEA Project: Road safety is not just a technology problem—it is a national imperative. We have built the technology, verified the code, and proven the concept. With your 10 Lakh Taka pre-seed grant and mentorship, we will make sure that no motorcycle rider in Bangladesh ever rides alone or unprotected.
>
> Thank you. জয় বাংলা, জয় বঙ্গবন্ধু।"

---

# Part 3: iDEA Selection Committee Defense & FAQ Cheat Sheet

Be prepared to answer these exact tough questions from the iDEA panel:

### Q1: "Dhaka has potholes, speed bumps, and erratic traffic. How do you prevent your crash detector from firing false alarms every 5 minutes?"
**Answer:**
> "That was the very first engineering problem we solved. A simple accelerometer spike triggers on any pothole. ThrottleIQ does NOT rely on a single acceleration threshold. Our `EventDetector` requires a multi-condition signature: a high-g impact spike AND a simultaneous jerk vector spike, followed within 2.0 seconds by a sharp drop in GPS speed to near zero (stopped vehicle). 
> Furthermore, even if an aggressive drop triggers the sensor, our system initiates a prominent 60-second audio-visual countdown with vibration and loud alarm beeps. A conscious rider who simply dropped their phone has a full minute to dismiss it with a single tap. Only an uncancelled countdown escalates to emergency contacts."

### Q2: "Why not use an external hardware GPS tracker like the ones available in the market for 3,000–5,000 BDT?"
**Answer:**
> "Hardware GPS trackers require wiring into the bike's battery, which frequently voids manufacturer warranties, drains the battery when parked, and requires buying and maintaining a separate SIM card with monthly recharges. Furthermore, Chinese hardware trackers offer zero intelligent crash impact detection, zero maintenance analytics, and no community features. 
> ThrottleIQ requires **zero hardware cost**. Every rider already owns a smartphone with high-precision accelerometers and GPS. By eliminating the hardware barrier, our adoption friction is zero."

### Q3: "Bangladeshi commuter riders are notoriously price-sensitive. How can you realistically make money?"
**Answer:**
> "We designed our financial strategy knowing that Bangladeshi commuters will not pay high upfront fees. That is why our core ride tracking and local maintenance alerts are free. 
> We monetize in three distinct ways: 
> 1. **High-Value Peace of Mind (B2C Pro):** Parents, spouses, and touring enthusiasts happily pay 99 BDT/month (less than the price of one liter of petrol) for automated SMS/call alerts to family. 
> 2. **B2B Fleet Telematics:** Logistics and courier companies (Foodpanda, Pathao, Steadfast) actively seek ways to monitor rider safety, reduce delivery accidents, and audit vehicle maintenance. At 150 BDT/bike/month, we provide an enterprise-grade fleet telematics dashboard at a fraction of hardware tracker costs. 
> 3. **Marketplace Monetization:** Local repair garages and spare parts retailers pay for featured listings in our verified POI directory."

### Q4: "What happens when a rider crashes in an area with zero mobile network coverage?"
**Answer:**
> "Our architecture is offline-first. All telemetry, crash event timestamps, and sensor curves are written locally to SQLite. While an SMS or web link requires cellular transmission to reach family, the app immediately activates maximum volume local audio distress sirens and displays the on-screen SafeQR medical card (blood group, allergies, emergency contact phone numbers). This allows on-scene bystanders or highway first-responders to immediately identify the victim and call for help, even without internet access."

### Q5: "What exactly will you deliver with the 10 Lakh BDT iDEA grant?"
**Answer:**
> "We will hit three non-negotiable milestones within 12 months:
> 1. Complete integration and licensing of local automated telecom SMS and voice-call gateways so emergency dispatch functions seamlessly nationwide.
> 2. Complete controlled physical track testing to calibrate our sensor algorithms with BRTA and safety consultants.
> 3. Public release on Google Play Store and Apple App Store, acquiring our first 50,000 active riders across Dhaka, Chattogram, and Sylhet."

---
*Prepared by Blankframe Technologies for the iDEA Project, ICT Division, Government of Bangladesh.*
