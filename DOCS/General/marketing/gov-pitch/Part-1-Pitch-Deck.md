# Part 1: Pitch Deck Guidelines (MS PowerPoint Presentation)
**iDEA Project Application | ICT Division, Government of Bangladesh**

---

## Visual Design Standards
- **Theme:** Modern Automotive Telematics (Dark Mode)
- **Colors:**
  - Background: Deep Carbon (`#121212`)
  - Accent / Primary: Electric Cyan (`#00E5FF`) & Safety Amber (`#FF9800`)
  - Typography: High-contrast Crisp White (`#FFFFFF`) and Muted Silver (`#A0A0A0`)
- **Typography:** Space Grotesk / Inter / Hind Siliguri (for Bangla text)
- **Formatting Rule:** Keep slides visual and concise. Use cards, diagrams, and callouts rather than long blocks of text.

---

## Slide 1: Introduction – Company

### Visual Layout
- Center-top: ThrottleIQ Speedometer Arc emblem (`app/assets/images/app_icon.svg`)
- Prominent Title and Bilingual Subtitle
- Lower third: Meta badge container (Testing stats, License, App ID)

### Slide Content
- **Product Name:** **ThrottleIQ**
- **Tagline:** *Machine Memory for Motorcycles*  
  *(রাইডের ডিজিটাল ব্ল্যাকবক্স ও সুরক্ষাকবচ)*
- **Organization:** Blankframe Technologies (`com.bft.throttleiq`)
- **Current Status:**
  - Pre-Launch Beta `1.0.0-beta.2.2+7`
  - Signed Android APK & Google Play Console Internal Track Live
  - 862 automated Flutter tests + 73 Firestore security tests passing green
- **Presenters:** Core Management Team
- **Contact:** Dhaka, Bangladesh | https://github.com/blankframe-tech/ThrottleIQ

### Speaker Notes
> "Respected members of the iDEA selection committee, good day. We are Blankframe Technologies, and today we present ThrottleIQ: an intelligent, smartphone-native telematics and crash safety platform designed specifically for the two-wheeler ecosystem of Bangladesh."

---

## Slide 2: Problem & Solution Scenario

### Visual Layout
- Split-screen comparison: Left side in muted red/amber ("The Crisis on Our Roads"), Right side in electric cyan/green ("The ThrottleIQ Solution").

### Slide Content
#### The Current Crisis in Bangladesh
1. **Unwitnessed Fatal Crashes:** Over 40% of road fatalities in Bangladesh involve motorcycles. On national highways (Dhaka-Chattogram, Bangabandhu Expressway) or rural routes, solitary riders who crash often remain unassisted during the critical Golden Hour.
2. **Zero Digital Telematics:** Unlike cars with onboard computers (OBD-II), 99% of motorcycles in Bangladesh lack digital diagnostics, telemetry, or crash awareness.
3. **Guesswork Maintenance:** Over 80% of riders track oil, chain slack, and brake wear by memory, leading to preventable breakdowns, fuel wastage, and steep resale loss.
4. **Foreign Apps Don't Fit:** Global apps (Strava, Rever) cost \$80+/yr, freeze when mobile networks drop on highways, ignore local mechanic ecosystems, and lack Bangla localization.

#### The ThrottleIQ Solution
- **Hardware-Less Black Box:** Turns standard smartphones into telematics computers using built-in sensors—zero hardware purchase or bike wiring needed.
- **Intelligent Crash Detection:** Sensor-fusion algorithm detects crash impact spikes + sudden speed drops, launching a 60-second audio alarm. If uncancelled, it broadcasts an emergency web link with live GPS, speed, and battery level.
- **100% Offline-First Architecture:** Records over 20 telematics points per second in complete cellular blackouts, auto-syncing when signal returns.
- **Distance-Based Maintenance:** Automatically updates service intervals for oil, chain, air filter, and tires based on real kilometers ridden.
- **Localized Ecosystem:** Dual English/Bangla interface with a crowdsourced directory of verified local mechanics, spare parts shops, and fuel stations.

### Speaker Notes
> "Motorcycles are the lifeline of Bangladesh's economy, yet two-wheelers account for over 40% of our fatal road crashes. When an accident happens on a dark highway, hours pass before family finds out. Simultaneously, riders spend thousands of Taka on avoidable repairs because they have no vehicle memory. ThrottleIQ turns the rider's smartphone into a life-saving black box and maintenance assistant, operating completely offline without requiring expensive external hardware."

---

## Slide 3: Market Size & Possibilities (TAM / SAM / SOM)

### Visual Layout
- Three concentric circle cards displaying TAM, SAM, and SOM with quantitative BDT figures and growth drivers.

### Slide Content
#### 1. Total Addressable Market (TAM)
- **4.5 Million+** Registered Motorcycles in Bangladesh (BRTA official records).
- **500,000+** New motorcycles registered annually.
- **BDT 1,500+ Crore (\$130M+ USD)** annual ecosystem spend in Bangladesh on maintenance, lubricants, spare parts, and fuel.

#### 2. Serviceable Addressable Market (SAM)
- **1.2 Million** Smartphone-equipped daily commuter and gig delivery riders in major urban corridors (Dhaka, Chattogram, Sylhet, Rajshahi).
- **250,000+** Active delivery and logistics riders working for platforms like Pathao, Foodpanda, Steadfast, and RedX.

#### 3. Serviceable Obtainable Market (SOM - 18 to 24 Months)
- **50,000 Active Monthly Riders** targeted through touring clubs, brand owner forums (Yamaha, Bajaj, TVS, Honda, Royal Enfield), and courier safety partnerships.
- **BDT 3.5 Crore** projected annual revenue across Pro subscriptions and B2B fleet dashboards.

### Speaker Notes
> "Our market is vast and growing at double-digit rates. Bangladesh has over 4.5 million registered motorcycles. Our immediate serviceable market consists of 1.2 million smartphone-carrying commuters and 250,000 gig riders who rely on their bikes every single day. Within 18 to 24 months, our target is capturing 50,000 active riders in Bangladesh before scaling across South Asia."

---

## Slide 4: Competitive Advantage & Unique Features

### Visual Layout
- Feature-by-feature matrix comparing ThrottleIQ against global fitness apps, Western motorcycle apps, and Chinese OBD hardware trackers.

### Slide Content

| Evaluation Dimension | Fitness Apps (Strava, Komoot) | Western Moto Apps (Rever, Detecht) | Hardware Trackers (OBD/GPS) | **ThrottleIQ (Blankframe)** |
| :--- | :--- | :--- | :--- | :--- |
| **Crash Detection** | ❌ None (Bicycle/run focus) | ⚠️ Fails without active 4G | ⚠️ Basic tilt-only sensor | ✅ **Impact + Speed-Drop Signature (Filters Potholes)** |
| **Emergency Live Link** | ⚠️ Behind \$80 paywall | ⚠️ Recipient must install app | ❌ Raw SMS coordinates only | ✅ **Token Link (Opens on any web browser)** |
| **Offline Resilience** | ❌ Loses data in dead zones | ❌ Freezes during weak signal | ⚠️ Requires continuous 2G SIM | ✅ **100% Offline SQLite Architecture** |
| **Maintenance Tracking** | ❌ None | ❌ Manual calendar dates | ❌ None | ✅ **Automatic km-Based Service Triggers** |
| **Hardware Barrier** | ✅ None | ✅ None | ❌ Costs BDT 3,500–8,000 + SIM | ✅ **Zero Hardware (Uses Phone Sensors)** |
| **Localization & POI** | ❌ Global only, English | ❌ Global only, English | ❌ None | ✅ **Bangla Language & Local Garage Directory** |
| **Pricing** | \$80 / year (BDT 9,500) | \$60 / year (BDT 7,200) | BDT 500/month recharge | **Free Core + BDT 99/month (Pro)** |

#### Proprietary Competitive Moats
1. **Pothole & Speed-Bump Filtering:** Calibrated specifically for rough South Asian asphalt.
2. **Zero Adoption Friction:** Zero hardware cost; works on budget Android smartphones.
3. **Local Garage Ecosystem:** Crowdsourced, rider-rated network of mechanics and parts shops.

### Speaker Notes
> "Why can't riders simply use Strava or Western apps? Because those apps cost 80 dollars a year, fail the moment signal drops on a rural highway, and have no concept of Bangladesh road conditions. Hardware trackers cost thousands of Taka and void bike warranties. ThrottleIQ is built rider-first, operates 100% offline, and costs a fraction of the price."

---

## Slide 5: What is Your Need? (Funding, Mentoring, Operations)

### Visual Layout
- Left: Donut chart / breakdown table of the BDT 10 Lakh grant allocation.  
- Right: Strategic non-financial partnerships requested from the iDEA Project.

### Slide Content
#### Financial Ask: BDT 10,00,000 (10 Lakh) Pre-Seed Grant (iDEA)

| Area of Investment | Amount (BDT) | % | Deliverables & Milestones |
| :--- | :--- | :--- | :--- |
| **Automated Emergency Dispatch Gateway** | **BDT 3,50,000** | 35% | Integrate local SMS/voice telecom gateways (SSL Wireless/Infobip) for carrier-level emergency alerts. |
| **Crash Sensor Track Calibration & Dummies** | **BDT 2,50,000** | 25% | Controlled track crash tests with test rigs to eliminate false alarms and benchmark crash accuracy. |
| **Public Store Rollouts & Cloud Infrastructure** | **BDT 2,00,000** | 20% | Public releases on Google Play Store & Apple App Store; Firebase Blaze cloud tier for scale. |
| **Garage Network Onboarding & Community Seeding** | **BDT 1,50,000** | 15% | Onboard 500+ local mechanics in Dhaka/Chattogram and partner with top touring clubs. |
| **Legal, Trade Licensing & IP Protection** | **BDT 50,000** | 5% | Trade license, software copyright filings, and data safety compliance. |
| **Total** | **BDT 10,00,000** | **100%** | **12-Month Milestone-Driven Execution** |

#### Operational & Mentorship Support Needed from iDEA:
- **Policy & Emergency Linkage:** Guidance on connecting with national emergency dispatch (`999`) and BRTA road safety initiatives.
- **Incubation Facilities:** Co-working space and testing desk at ICT Tower, Agargaon, Dhaka.
- **Enterprise Introductions:** Pilot facilitation with logistics and ride-sharing fleets (e.g. e-Courier, Pathao, Foodpanda).

### Speaker Notes
> "We are seeking the BDT 10 Lakh Pre-Seed Grant from the iDEA Project. We have budgeted every Taka toward clear milestones: 35% to deploy our automated emergency SMS and voice gateway, 25% for physical crash-sensor calibration tests, 20% for app store launches and cloud infrastructure, and 15% for garage onboarding. From iDEA, we also look for mentorship and institutional support to align with national road safety initiatives."

---

## Slide 6: Technology Strategy & Architecture

### Visual Layout
- Multi-tier system architecture diagram showing Client Engine, Storage Layer, and Cloud Infrastructure.

### Slide Content
```
┌────────────────────────────────────────────────────────────────────────────┐
│                             CLIENT LAYER                                   │
│  Flutter (Dart) • Cross-Platform (Android & iOS)                           │
│  ├─ Sensor Fusion Engine (20 Hz Accelerometer + Gyroscope + GPS Delta)     │
│  ├─ EventDetector (Calculates deceleration curves & crash signatures)      │
│  ├─ VehicleStateEstimator (Filters potholes, bumps, and stationary stops)  │
│  └─ Battery-Aware Foreground Task Manager                                  │
└─────────────────────────────────────┬──────────────────────────────────────┘
                                      │
┌─────────────────────────────────────▼──────────────────────────────────────┐
│                        OFFLINE-FIRST STORAGE LAYER                         │
│  ├─ Local SQLite Database (ACID-compliant single source of truth)          │
│  ├─ Transactional Outbox Pattern (Guaranteed zero data loss on dropouts)  │
│  └─ SafeQR Emergency Card (Device-encrypted medical data)                 │
└─────────────────────────────────────┬──────────────────────────────────────┘
                                      │ Async Incremental Sync
┌─────────────────────────────────────▼──────────────────────────────────────┐
│                        FIREBASE CLOUD INFRASTRUCTURE                       │
│  ├─ Cloud Firestore: Encrypted user telemetry and garage POI repository    │
│  ├─ Cloud Functions (Node.js/TS): Emergency token generation & escalation │
│  ├─ Geohash Engine: High-speed spatial queries for nearby mechanics/fuel   │
│  └─ Firebase Crashlytics: Real-time telemetry health and diagnostic logs  │
└────────────────────────────────────────────────────────────────────────────┘
```

#### Key Architectural Highlights
- **Engineered to QA Gate Standards:** 862 automated Flutter tests and 73 Firestore security tests.
- **Zero Sideloading Latency:** Incremental transactional sync prevents battery drain and bandwidth consumption.

### Speaker Notes
> "On the technical front, ThrottleIQ is built on an enterprise-grade, offline-first Flutter architecture. Our proprietary sensor engine samples motion dynamics 20 times a second, executing real-time jerk profiling and speed derivatives to confirm crash signatures. All telemetry is stored locally in an ACID SQLite database using a Transactional Outbox pattern, ensuring that not a single byte of ride data is lost when passing through cellular dead zones."

---

## Slide 7: Business Strategy & Go-To-Market (GTM)

### Visual Layout
- 3-Phase Gantt timeline highlighting user acquisition, enterprise pilots, and marketplace scaling.

### Slide Content
#### Phase 1: Grassroots Community Seeding (Months 1–4)
- **Motorcycle Club Partnerships:** Direct onboarding with 15+ major Bangladeshi riding clubs (Yamaha FZ-S Club, Honda Hornet BD, Royal Enfield BD, Pulsar Club).
- **Influencer Demonstrations:** Collaborations with leading moto vloggers demonstrating real highway offline tracking and live safety links.
- **Localized Brand Messaging:** Street and digital campaigns focused on *"Works when your signal doesn't"* (*"সিগন্যাল না থাকলেও রেকর্ড হতে থাকে"*).

#### Phase 2: B2B Fleet Pilots (Months 5–8)
- **Gig Worker Safety Dashboard:** Pilots with courier and food delivery companies (Foodpanda, Pathao, Steadfast).
- **Enterprise Value:** Real-time driver risk scores, accident liability reduction, and scheduled fleet maintenance tracking.

#### Phase 3: Garage Marketplace & Insurance Linkages (Months 9–12+)
- **Verified Mechanic SafeSpots:** Free directory listing for local garages in exchange for referring riders to the app.
- **Insurance Telematics:** Partnership discussions with general insurance providers for usage-based rider safety discounts.

### Speaker Notes
> "Our Go-To-Market plan is structured in three logical phases: first, grassroots community adoption across Bangladesh's passionate motorcycle touring clubs; second, B2B fleet safety dashboards for commercial courier and food delivery riders; and third, onboarding local repair garages as verified service points, creating a sustainable, self-reinforcing ecosystem."

---

## Slide 8: Financial Strategy, Pricing & Revenue Projections

### Visual Layout
- Revenue stream cards alongside a 3-Year financial projection table showing path to profitability.

### Slide Content
#### Diversified Revenue Streams
1. **B2C Freemium Core (Free Forever):** Unlimited offline ride tracking, route analytics, local maintenance reminders, and cancellable crash countdown.
2. **ThrottleIQ Pro (BDT 99/month or BDT 899/year):** Automated SMS/Call crash dispatch to family, unlimited cloud backup, GPX export, and advanced lean-angle telemetry.
3. **B2B Fleet Safety SaaS (BDT 150/bike/month):** Dispatcher portal, driver safety league tables, and maintenance audit logs.
4. **Verified Marketplace Listings (BDT 300–500/month/garage):** Featured placement for aftermarket spare-parts shops and service centers.

#### 3-Year Financial Projections (in BDT)

| Metric | Year 1 | Year 2 | Year 3 |
| :--- | :--- | :--- | :--- |
| **Total Registered Users** | 50,000 | 250,000 | 750,000 |
| **Pro Subscribers (B2C @ ~4%)** | 2,000 | 12,500 | 45,000 |
| **B2B Tracked Fleet Bikes** | 500 | 3,000 | 12,000 |
| **B2C Subscription Revenue** | BDT 18,00,000 | BDT 1,12,50,000 | BDT 4,05,00,000 |
| **B2B Fleet SaaS Revenue** | BDT 9,00,000 | BDT 54,00,000 | BDT 2,16,00,000 |
| **Directory & Partner Revenue** | BDT 1,50,000 | BDT 9,50,000 | BDT 35,00,000 |
| **Total Gross Revenue** | **BDT 28,50,000** | **BDT 1,76,00,000** | **BDT 6,56,00,000** |
| **Operating Costs (SMS, Cloud, Ops)** | BDT 21,00,000 | BDT 85,00,000 | BDT 2,40,00,000 |
| **Net Profit / (Loss)** | **+ BDT 7,50,000** | **+ BDT 91,00,000** | **+ BDT 4,16,00,000** |

*High operating margins (>75%) achieved due to smartphone-edge computing and serverless backend architecture.*

### Speaker Notes
> "We monetize through a sustainable freemium model. Core offline ride recording is free forever. For 99 Taka a month—less than the price of a liter of petrol—riders get Pro automated emergency SMS and call dispatch. On the enterprise side, logistics companies pay 150 Taka per bike monthly for fleet safety monitoring. This model yields positive cash flow in Year 1, scaling to over 6 Crore Taka in revenue by Year 3."

---

## Slide 9: Management Team & Execution Track Record

### Visual Layout
- Professional portraits of core team members with skill tags, company achievements, and advisor logos.

### Slide Content
- **Founder & Lead Software Architect:**
  - Full-stack mobile & cloud systems engineer.
  - Architected the 862-test offline-first engine, sensor calculators, and transactional sync pipeline.
- **Embedded & Sensor Systems Lead:**
  - Background in robotics and IoT signal processing.
  - Oversees accelerometer calibration, vibration filtering, and vehicle state estimation.
- **Growth & Community Lead:**
  - Active touring rider with direct relationships across 20+ motorcycle clubs in Bangladesh.
  - Leads local garage onboarding, user acquisition, and community trust.
- **Advisory Board:**
  - Senior Automotive Safety Specialist (Road safety protocols & crash biomechanics).
  - ICT Regulatory & Legal Advisor (Data privacy, BRTA compliance).

#### Proven Execution Track Record
- Built and tagged version `1.0.0-beta.2.2+7` with zero external capital.
- 862 automated domain tests + 73 security-rule tests passing green.
- Deployed on Google Play Console internal testing track.

### Speaker Notes
> "Behind ThrottleIQ is a dedicated team combining deep mobile systems engineering, signal processing, and direct community trust. We haven't just talked about this problem—we've written over 800 passing tests and shipped a live beta build. With the support and mentorship of the iDEA Project, we are ready to take ThrottleIQ nationwide. Thank you."
