# ThrottleIQ — Master iDEA Grant Application & Pitch Package
**ICT Division, Ministry of Posts, Telecommunications and Information Technology**  
*Innovation Design and Entrepreneurship Academy (iDEA) Project*

- **Application Category:** Pre-Seed Grant (BDT 10,00,000 / 10 Lakh)
- **Product:** ThrottleIQ
- **Entity:** Blankframe Technologies (`com.bft.throttleiq`)
- **Official Submission URL:** [idea.gov.bd/p/10/how-to-apply](https://idea.gov.bd/p/10/how-to-apply)

---

# Executive Summary

In Bangladesh, over **4.5 million motorcycles** are registered with the BRTA, with more than **500,000 new two-wheelers** added every year. Motorcycles are the backbone of rapid urban transport and last-mile commerce. Yet, two-wheelers account for over **40% of all road crash fatalities in Bangladesh**. When an accident occurs on a national highway or isolated rural corridor, emergency assistance is delayed because no one knows a crash has occurred until it is too late. Furthermore, riders have no digital tool to monitor vehicle health, tracking maintenance with arbitrary guesswork that leads to mechanical failures and costly breakdowns.

**ThrottleIQ** transforms any standard Android or iOS smartphone into an intelligent, hardware-less motorcycle telematics "black box." Using proprietary multi-sensor fusion algorithms (accelerometer, gyroscope, GPS velocity derivatives), ThrottleIQ detects crash impact signatures, initiates a 60-second cancellable audio-visual countdown to filter out potholes and false alarms, and automatically shares a live, encrypted emergency location link with designated loved ones. Crucially, ThrottleIQ is built **100% offline-first**: all ride telematics, telemetry curves, and maintenance triggers operate reliably even in complete cellular dead zones, synchronizing seamlessly with cloud servers when network connectivity resumes.

With a fully functioning app (`862 unit & domain tests, 73 Firestore security tests`), verified Android APK, and Play Console deployment, ThrottleIQ is seeking a **10 Lakh BDT Pre-Seed Grant** from the iDEA Project to scale its automated SMS/voice emergency dispatch infrastructure, complete nationwide crash-calibration testing, and onboard 50,000 riders in Bangladesh.

---

# Part 1: Pitch Deck (Slide-by-Slide PowerPoint Structure)

## Slide 1: Introduction – Company
- **Visual Header:** ThrottleIQ Speedometer Arc Emblem
- **Tagline:** Machine Memory for Motorcycles (*রাইডের ডিজিটাল ব্ল্যাকবক্স ও সুরক্ষাকবচ*)
- **Company Name:** Blankframe Technologies (`com.bft.throttleiq`)
- **Key Snapshot:**
  - **What we do:** AI-powered smartphone telematics, crash detection, and predictive maintenance for two-wheelers.
  - **Status:** Fully functional working beta (`1.0.0-beta.2.2+7`), 862+ automated tests green, signed APK & Play Console internal track.
  - **Mission:** Zero unwitnessed motorcycle crashes and data-driven vehicle longevity for every rider in Bangladesh.
- **Presenter Names:** Founder & Lead Architect / Core Management Team
- **Contact:** info@throttleiq.com | Dhaka, Bangladesh | https://github.com/blankframe-tech/ThrottleIQ

---

## Slide 2: Problem & Solution Scenario
### The Problem (Current Bangladesh Reality)
1. **The Unseen Highway Tragedy:** Over 40% of road accident fatalities in Bangladesh involve two-wheelers. On long highway stretches (Dhaka–Chattogram, Bangabandhu Expressway) or rural bypasses, solo riders who crash remain unassisted for the critical "Golden Hour."
2. **Zero Telematics for Two-Wheelers:** Unlike modern passenger cars equipped with OBD-II computers, 99% of motorcycles in Bangladesh have zero digital diagnostics or data memory.
3. **Guesswork Maintenance & High Depreciation:** Over 80% of riders track engine oil, chain lubrication, and brake wear by guesswork, leading to roadside breakdowns, fuel wastage, and lost resale value in a high-turnover used market.
4. **Existing Apps Fail Local Needs:** Foreign apps (Strava, Rever, Calimoto) are built for cyclists or luxury Western sports bikes; they fail in mobile dead zones, require costly \$10+/month subscriptions, lack local repair garage directories, and have no Bangla support.

### The Solution (ThrottleIQ)
- **Smartphone-Only Black Box:** Transforms the rider's phone into an onboard computer with zero extra hardware or wiring modifications required.
- **Real-Time Signature Crash Detection:** Sensor-fusion algorithm (impact acceleration spike + rapid velocity drop) initiates a 60-second audio-visual alarm. If uncancelled, it broadcasts an unguessable emergency token link displaying live GPS location, battery percentage, and speed.
- **True Offline-First Architecture:** 100% functional without mobile data. Telemetry is saved locally in an ACID SQLite database and syncs when back online.
- **Distance-Based Garage Memory:** Service intervals for engine oil, drive chain, air filter, and tires are automatically tracked against actual kilometers ridden.
- **Localized Rider Ecosystem:** Built-in community directory of verified fuel stations, repair mechanics, and spare parts shops, with full dual English/Bangla language support.

---

## Slide 3: Market Size & Possibilities (TAM / SAM / SOM)
### Bangladesh Market Opportunity
- **Total Addressable Market (TAM):**
  - **4.5 Million+** Registered Motorcycles in Bangladesh (BRTA official records).
  - Annual two-wheeler economic expenditure (fuel, consumables, maintenance, insurance): **BDT 1,500+ Crore (\$130M+ USD)**.
- **Serviceable Addressable Market (SAM):**
  - **1.2 Million** Smartphone-equipped urban commuters and gig delivery riders (Dhaka, Chattogram, Sylhet, Rajshahi).
  - Includes ~250,000 active delivery riders working with ride-sharing and logistics fleets (Pathao, Foodpanda, Shohoz, Steadfast, RedX).
- **Serviceable Obtainable Market (SOM - 18 to 24 Months):**
  - **50,000 Active Monthly Riders** targeted through motorcycle touring clubs, brand enthusiast communities, and delivery fleet partnerships.
  - Projecting BDT 3.5 Crore annual recurring revenue across consumer subscriptions and B2B fleet safety dashboards.

---

## Slide 4: Competitive Advantage & Unique Features

| Evaluation Criteria | Global Fitness Apps (Strava, Komoot) | Western Moto Apps (Rever, Detecht) | Hardware OBD Trackers | **ThrottleIQ (Blankframe Tech)** |
| :--- | :--- | :--- | :--- | :--- |
| **Crash Detection** | ❌ None (Bicycle/Run focus) | ⚠️ Requires active 4G data | ⚠️ Basic tilt sensor only | ✅ **Impact + Speed-Drop Signature (Filters Potholes)** |
| **Emergency Live Link** | ⚠️ Paid paywall | ⚠️ Account required by recipient | ❌ SMS only, no map | ✅ **Token-Based Link (Openable on any browser)** |
| **Network Resilience** | ❌ Fails on weak signal | ❌ Dropped rides | ⚠️ Dependent on 2G SIM | ✅ **100% Offline-First SQLite Architecture** |
| **Maintenance Tracking** | ❌ None | ❌ Manual date entry | ❌ None | ✅ **Automatic km-Based Service Triggers** |
| **Hardware Requirement** | ✅ None | ✅ None | ❌ Costs BDT 3,500 - 8,000 + SIM | ✅ **Zero Hardware (Uses Phone Sensors)** |
| **Localization & POI** | ❌ None | ❌ None | ❌ None | ✅ **Bangla Language & Local Garage Directory** |
| **Price Point** | \$80 / year (BDT 9,500) | \$60 / year (BDT 7,200) | BDT 500/month recharge | **Freemium + BDT 99/mo (Pro)** |

---

## Slide 5: What is Your Need? (Funding, Mentoring, Resources)

### Financial Ask: BDT 10,00,000 (10 Lakh) Pre-Seed Grant (iDEA)

| Allocation Area | Amount (BDT) | Percentage | Strategic Deliverable |
| :--- | :--- | :--- | :--- |
| **Automated Emergency Dispatch Infrastructure** | **BDT 3,50,000** | 35% | Integrate local SMS/voice telecom gateways (SSL Wireless/Infobip) to enable automatic phone call and SMS alerts when crash countdown expires. |
| **Crash Sensor Calibration & Field Testing** | **BDT 2,50,000** | 25% | Controlled track crash testing with crash dummies and telemetry rigs to eliminate false positives and certify crash-signature accuracy. |
| **App Store Launches & Cloud Infrastructure** | **BDT 2,00,000** | 20% | Production Google Play Console & Apple App Store public releases, Firebase Blaze scalable serverless capacity. |
| **Community Seeding & Garage Network Onboarding** | **BDT 1,50,000** | 15% | Onboarding 500+ local motorcycle mechanics/garages in Dhaka & Chattogram with verified ThrottleIQ SafeSpot badges. |
| **Regulatory & IP Protection** | **BDT 50,000** | 5% | Trade licensing, data protection compliance, and intellectual property / trademark filings. |
| **Total** | **BDT 10,00,000** | **100%** | **Milestone-driven execution across 12 months** |

---

## Slide 6: Technology Strategy & Architecture
- **Client Tier:** Flutter (Dart) mobile application with Riverpod reactive architecture.
- **Sensor Engine:** 20 Hz multi-sensor sampling with adaptive jerk profiling to eliminate noise and pothole artifacts.
- **Storage Tier:** Local SQLite database with a Transactional Outbox pattern guaranteeing zero lost bytes.
- **Cloud Backend:** Firebase Cloud Firestore for asynchronous sync; Cloud Functions for serverless emergency token generation.

---

## Slide 7: Business Strategy & Go-To-Market (GTM)
- **Phase 1: Grassroots Touring Clubs (Months 1–4):** Seeding across 15+ Bangladesh motorcycle touring clubs (Yamaha FZ/R15, Hornet BD, Pulsar BD, Royal Enfield) and moto vloggers.
- **Phase 2: B2B Fleet Pilots (Months 5–8):** Commercial rollouts for food delivery and courier riders with safety scorecards.
- **Phase 3: Garage Marketplace (Months 9–12+):** Free directory placement for mechanics in exchange for rider referrals.

---

## Slide 8: Financial Strategy, Pricing & Revenue Projections

### 3-Year Financial Forecast (in BDT)

| Metric | Year 1 | Year 2 | Year 3 |
| :--- | :--- | :--- | :--- |
| **Total Registered Users** | 50,000 | 250,000 | 750,000 |
| **Pro Subscribers (B2C @ ~4%)** | 2,000 | 12,500 | 45,000 |
| **B2B Tracked Fleet Bikes** | 500 | 3,000 | 12,000 |
| **B2C Subscription Revenue** | BDT 18,00,000 | BDT 1,12,50,000 | BDT 4,05,00,000 |
| **B2B Fleet SaaS Revenue** | BDT 9,00,000 | BDT 54,00,000 | BDT 2,16,00,000 |
| **Directory & Partner Revenue** | BDT 1,50,000 | BDT 9,50,000 | BDT 35,00,000 |
| **Total Gross Revenue** | **BDT 28,50,000** | **BDT 1,76,00,000** | **BDT 6,56,00,000** |
| **Operating Expenses** | BDT 21,00,000 | BDT 85,00,000 | BDT 2,40,00,000 |
| **Net Profit / (Loss)** | **+ BDT 7,50,000** | **+ BDT 91,00,000** | **+ BDT 4,16,00,000** |

---

## Slide 9: Management Team & Execution Track Record
- **Founder & Lead Software Architect:** Full-stack engineer who architected the 862-test offline-first engine and motion calculators.
- **Embedded & Sensor Systems Lead:** Robotics and IoT signal processing specialist.
- **Growth & Community Lead:** Active motorcycle community organizer connected with regional clubs.
- **Advisory Board:** Automotive road safety consultants and senior infrastructure architects.

---

# Part 2: 5-Minute Timed Video Pitch Script

### [0:00 – 0:40] Problem Statement (Founder & CEO)
> "Assalamu Alaikum and good day, honorable evaluators of the iDEA Project.
>
> In Bangladesh, over 4.5 million motorcycles navigate our streets every day. Two-wheelers are the lifeblood of our economy, rapid urban transit, and last-mile commerce.
>
> But there is an alarming human cost. Motorcycles account for more than 40% of all road crash fatalities in our country. When an accident strikes on a national highway or a dark rural bypass, hours often pass before anyone realizes what happened. The rider misses the critical medical Golden Hour, turning survivable accidents fatal.
>
> At the same time, riders have zero onboard intelligence. Bike maintenance is managed through fading memory or notebooks, leading to preventable mechanical failures, highway breakdowns, and lost resale value."

### [0:40 – 1:15] The Product & Solution (Founder & CEO)
> "We built **ThrottleIQ** to solve this. ThrottleIQ turns any standard smartphone into an intelligent black box and lifesaver for motorcycles—with zero expensive hardware needed.
>
> First, **Intelligent Crash Detection**. ThrottleIQ continuously monitors motion dynamics. When it senses a high-impact spike followed by an immediate drop in speed, it triggers a loud 60-second audio-visual alarm. If the rider is unharmed or simply dropped their phone, they cancel it with a single tap. If they are unresponsive, ThrottleIQ instantly broadcasts an encrypted emergency web link with their exact live GPS location, speed, and battery level to their family.
>
> Second, **Machine Memory**. ThrottleIQ automatically tracks engine oil, chain slack, brake pads, and tires against actual kilometers ridden, notifying the rider the exact day service is due."

### [1:15 – 1:50] Target Market & Market Size (Growth Lead)
> "Who are we serving? In Bangladesh alone, our Total Addressable Market is over 4.5 million registered motorcycles—representing an annual expenditure of more than 1,500 Crore Taka in fuel, consumables, and maintenance.
>
> Our immediate serviceable market encompasses 1.2 million smartphone-carrying daily commuters in Dhaka, Chattogram, and Sylhet, alongside 250,000 gig delivery riders working for platforms like Pathao, Foodpanda, and Steadfast.
>
> Within 18 to 24 months, our Serviceable Obtainable Market target is **50,000 active monthly riders**, giving ThrottleIQ a self-sustaining, profitable foundation in Bangladesh before expanding regionally."

### [1:50 – 2:25] Business Model & Revenue Streams (Growth Lead)
> "Our business model is engineered around accessibility and high-margin software:
>
> 1. **B2C Freemium Core:** Essential offline ride recording, trip analytics, and local emergency links are 100% free forever.
> 2. **ThrottleIQ Pro:** At just 99 Taka a month or 899 Taka a year—less than the price of a single liter of petrol—riders get automated emergency SMS and phone-call dispatch, lifetime cloud backups, and lean-angle telemetry.
> 3. **B2B Fleet Safety Dashboard:** Courier and delivery logistics companies pay 150 Taka per bike monthly for live fleet safety monitoring, driver risk scores, and automated fleet maintenance scheduling.
> 4. **Verified Garage Network:** Local repair shops pay a monthly listing fee to be featured as certified service hubs in our rider directory."

### [2:25 – 3:00] Traction, Competition & The Ask (Founder & CEO)
> "Where do we stand today? ThrottleIQ is not an unproven concept. We have built and tagged version `1.0.0-beta.2.2`, backed by 862 automated tests, with a signed build running on the Google Play Console internal testing track!
>
> While global apps like Strava or Rever charge 10 dollars a month and freeze the moment cellular signal drops, ThrottleIQ is 100% offline-first, fully bilingual in Bangla, and tailored to local road conditions.
>
> To take this protection to every rider in Bangladesh, we are seeking the **10 Lakh BDT Pre-Seed Grant** from the iDEA Project. This funding will scale our automated telecom SMS/voice gateway, support controlled track crash-calibration testing, and fund our public launch on Google Play and the App Store."

### [3:00 – 4:00] Technical Architecture (Technical Lead)
> "Two-wheeler telematics on a mobile device presents severe engineering challenges: intense road vibrations, phone orientation shifts, and chronic cellular dead zones on national highways.
>
> We engineered ThrottleIQ on a resilient, three-layer architecture:
>
> 1. **Edge Sensor Fusion:** Written in Flutter and Dart, our engine samples 3-axis accelerometers and GPS velocity derivatives 20 times every second. Our adaptive `EventDetector` uses jerk profiling to distinguish a genuine highway impact from a pothole, speed breaker, or sudden brake.
>
> 2. **True Offline-First Storage:** Most apps fail when connectivity drops. ThrottleIQ utilizes a local SQLite database coupled with an ACID-compliant Transactional Outbox pattern. Even if you ride through 100 kilometers of complete cellular blackout, zero data is lost. The moment signal returns, the app syncs incrementally to Firebase Cloud Firestore.
>
> 3. **Serverless Escalation & Encrypted Web Access:** Our Firebase Cloud Functions generate unguessable 24-hour cryptographic tokens. Anxious family members do not even need to install the app—they click a text link on any browser to view live GPS maps, speed, and battery levels.
>
> Our codebase is production-hardened: **862 automated domain tests and 73 security rules** run green on every single build."

### [4:00 – 5:00] Management Team & Closing (Founder & Core Team)
> "Behind ThrottleIQ is a team with the technical competence and personal passion to execute:
>
> I am the Founder and Lead Systems Architect at Blankframe Technologies. I've engineered real-time distributed applications, mobile sensor pipelines, and architected ThrottleIQ's offline engine from the first line of code.
>
> Our Technical Lead brings deep expertise in embedded systems, robotics, and accelerometer signal processing.
>
> And our Growth Lead is an active touring rider with established networks across more than twenty motorcycle clubs and local garage unions in Dhaka and Chattogram.
>
> We are advised by senior automotive road safety consultants and software architects.
>
> Honorable evaluators: Road safety is not merely an engineering challenge—it is a vital pillar of the Smart Bangladesh vision. We have built the technology, verified the code, and proven the market demand. 
>
> With your 10 Lakh Taka pre-seed grant, mentorship, and institutional support, we will ensure that no motorcycle rider in Bangladesh ever rides alone or unprotected.
>
> Thank you very much. Joy Bangla, Joy Bangabandhu."

---

# Part 3: Selection Committee Defense Summary

- **Pothole vs Crash Accuracy:** Multi-condition threshold requires high-g impact spike + simultaneous jerk vector spike + speed drop to near-zero within 2 seconds. A 60-second cancellable audio alarm prevents false dispatches.
- **Hardware vs App:** Zero installation cost, zero warranty voiding on new bikes, zero battery drain.
- **Commuter Monetization:** High-margin B2B fleet dashboards (BDT 150/bike/month) and peace-of-mind family subscription (BDT 99/month), complemented by garage marketplace fees.
- **Offline Dead Zones:** Audio siren fires locally, SafeQR emergency medical card displays on phone screen for bystanders, and outbox queues cloud broadcast for the first signal reconnection.
- **Smart Bangladesh Alignment:** Real-time road safety data, reduced fatal emergency response times, and formalization of local motorcycle workshops.
