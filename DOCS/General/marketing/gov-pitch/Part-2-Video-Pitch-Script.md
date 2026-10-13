# Part 2: Video Pitch Guidelines & 5-Minute Timed Script
**iDEA Project Application | ICT Division, Government of Bangladesh**

---

## 🎬 General Recording Instructions
- **Maximum Duration:** Strictly **5 minutes (300 seconds)**. Exceeding 300 seconds leads to automatic scoring penalties.
- **Video Format:** 1080p Full HD (`.mp4` or `.avi`). Clean audio (lavalier/lapel microphone recommended).
- **Presentation Dynamics:**
  - **Do NOT read monotonously from slides.** Speak directly to the camera with conversational clarity and energy.
  - **Team Participation:** All core team members (Founder/CEO, Tech Lead, Growth Lead) must actively speak on camera.
  - **Visual Elements:** Display high-contrast PowerPoint slides cleanly beside speakers, or cut between the speakers and screen captures of the live ThrottleIQ app running on an actual mounted smartphone.

---

## ⏱️ Timeline & Section Allocation

| Segment | Allocated Time | Target Range | Key Topics Covered |
| :--- | :--- | :--- | :--- |
| **Section 1: Business Plan** | **3 Minutes (180s)** | 0:00 – 3:00 | Problem, Solution, Market (TAM/SAM/SOM), Monetization, Traction, Competition & Ask |
| **Section 2: Technical Architecture** | **1 Minute (60s)** | 3:00 – 4:00 | Sensor Fusion, Offline-First SQLite, Outbox Sync, Security & Test Coverage |
| **Section 3: Management Team** | **1 Minute (60s)** | 4:00 – 5:00 | Founder & Team Credentials, Advisory Board, Vision & Closing |

---

# 📜 Word-for-Word Video Script

## Section 1: Business Plan (0:00 – 3:00)

### [0:00 – 0:40] The Problem & The Bangladesh Road Reality
**Visual:** Founder/CEO on camera. Clean studio or workshop setting with a motorcycle and handlebar-mounted phone in background. Slide 2 appears on side-screen.

**Speaker: Founder & CEO**
> "Assalamu Alaikum and good day, honorable evaluators of the iDEA Project.
>
> In Bangladesh, over 4.5 million motorcycles navigate our streets every day. Two-wheelers are the lifeblood of our economy, rapid urban transit, and last-mile commerce.
>
> But there is an alarming human cost. Motorcycles account for more than 40% of all road crash fatalities in our country. When an accident strikes on a national highway or a dark rural bypass, hours often pass before anyone realizes what happened. The rider misses the critical medical Golden Hour, turning survivable accidents fatal.
>
> At the same time, riders have zero onboard intelligence. Bike maintenance is managed through fading memory or notebooks, leading to preventable mechanical failures, highway breakdowns, and lost resale value."

---

### [0:40 – 1:15] The Product & Solution
**Visual:** Quick cut to phone running ThrottleIQ in ride mode. Zoom in on live speedometer, followed by the 60-second crash alarm countdown screen.

**Speaker: Founder & CEO**
> "We built **ThrottleIQ** to solve this. ThrottleIQ turns any standard smartphone into an intelligent black box and lifesaver for motorcycles—with zero expensive hardware needed.
>
> First, **Intelligent Crash Detection**. ThrottleIQ continuously monitors motion dynamics. When it senses a high-impact spike followed by an immediate drop in speed, it triggers a loud 60-second audio-visual alarm. If the rider is unharmed or simply dropped their phone, they cancel it with a single tap. If they are unresponsive, ThrottleIQ instantly broadcasts an encrypted emergency web link with their exact live GPS location, speed, and battery level to their family.
>
> Second, **Machine Memory**. ThrottleIQ automatically tracks engine oil, chain slack, brake pads, and tires against actual kilometers ridden, notifying the rider the exact day service is due."

---

### [1:15 – 1:50] Target Market & Market Size
**Visual:** Growth Lead steps forward. Slide 3 (TAM/SAM/SOM breakdown) displays prominently.

**Speaker: Growth & Community Lead**
> "Who are we serving? 
>
> In Bangladesh alone, our Total Addressable Market is over 4.5 million registered motorcycles—representing an annual expenditure of more than 1,500 Crore Taka in fuel, consumables, and maintenance.
>
> Our immediate serviceable market encompasses 1.2 million smartphone-carrying daily commuters in Dhaka, Chattogram, and Sylhet, alongside 250,000 gig delivery riders working for platforms like Pathao, Foodpanda, and Steadfast.
>
> Within 18 to 24 months, our Serviceable Obtainable Market target is **50,000 active monthly riders**, giving ThrottleIQ a self-sustaining, profitable foundation in Bangladesh before expanding regionally."

---

### [1:50 – 2:25] Business Model & Revenue Streams
**Visual:** Slide 8 (Pricing & Financial Projections) displayed with clean graphic cards.

**Speaker: Growth & Community Lead**
> "Our business model is engineered around accessibility and high-margin software:
>
> 1. **B2C Freemium Core:** Essential offline ride recording, trip analytics, and local emergency links are 100% free forever.
> 2. **ThrottleIQ Pro:** At just 99 Taka a month or 899 Taka a year—less than the price of a single liter of petrol—riders get automated emergency SMS and phone-call dispatch, lifetime cloud backups, and lean-angle telemetry.
> 3. **B2B Fleet Safety Dashboard:** Courier and delivery logistics companies pay 150 Taka per bike monthly for live fleet safety monitoring, driver risk scores, and automated fleet maintenance scheduling.
> 4. **Verified Garage Network:** Local repair shops pay a monthly listing fee to be featured as certified service hubs in our rider directory."

---

### [2:25 – 3:00] Traction, Competition & The Ask
**Visual:** Founder steps back in. Cut to Slide 4 (Competitive Matrix) and Slide 5 (Grant Allocation).

**Speaker: Founder & CEO**
> "Where do we stand today? ThrottleIQ is not an unproven concept. We have built and tagged version `1.0.0-beta.2.2`, backed by 862 automated tests, with a signed build running on the Google Play Console internal testing track!
>
> While global apps like Strava or Rever charge 10 dollars a month and freeze the moment cellular signal drops, ThrottleIQ is 100% offline-first, fully bilingual in Bangla, and tailored to local road conditions.
>
> To take this protection to every rider in Bangladesh, we are seeking the **10 Lakh BDT Pre-Seed Grant** from the iDEA Project. This funding will scale our automated telecom SMS/voice gateway, support controlled track crash-calibration testing, and fund our public launch on Google Play and the App Store."

---

## Section 2: Technical Architecture (3:00 – 4:00)

**Visual:** Technical Lead steps up in front of an interactive architectural diagram (Slide 6). Cut briefly to developer environment showing automated test suite running green.

**Speaker: Technical & Systems Lead**
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

---

## Section 3: Management Team & Commitment (4:00 – 5:00)

**Visual:** All three team members standing together on camera, confident and professional. Slide 9 displayed on screen.

**Speaker: Founder & CEO**
> "Behind ThrottleIQ is a team with the technical competence and personal passion to execute:
>
> I am the Founder and Lead Systems Architect at Blankframe Technologies. I've engineered real-time distributed applications, mobile sensor pipelines, and architected ThrottleIQ's offline engine from the first line of code.
>
> Our Technical Lead brings deep expertise in embedded systems, robotics, and accelerometer signal processing.
>
> And our Growth Lead is an active touring rider with established networks across more than twenty motorcycle clubs and local garage unions in Dhaka and Chattogram.
>
> We are advised by senior automotive road safety consultants and software architects."

*(Brief pause, team leans in with strong eye contact)*

**Speaker: Founder & CEO**
> "Honorable evaluators: Road safety is not merely an engineering challenge—it is a vital pillar of the Smart Bangladesh vision. We have built the technology, verified the code, and proven the market demand. 
>
> With your 10 Lakh Taka pre-seed grant, mentorship, and institutional support, we will ensure that no motorcycle rider in Bangladesh ever rides alone or unprotected.
>
> Thank you very much. Joy Bangla, Joy Bangabandhu."

*(Visual: ThrottleIQ Logo, App ID `com.bft.throttleiq`, Contact Info, and iDEA Logo fade in to screen. Timer hits 4:58 – 5:00).*
