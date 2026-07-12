




📄 PRODUCT REQUIREMENTS DOCUMENT (PRD)

🏷 Product Name

ThrottleIQ

🧭 Tagline

Ride smarter. Track deeper. Remember forever.



1. 🎯 PRODUCT VISION

ThrottleIQ is a motorcycle-first tracking, intelligence, and memory platform that:

Tracks rides with precision

Provides actionable maintenance insights

Detects riding patterns (including jerk, braking, acceleration)

Builds long-term emotional value via ride history and memory



---

2. 🎯 OBJECTIVES

Primary Goals

Deliver best-in-class ride tracking experience

Solve maintenance + odometer gap for bikes

Create daily utility → high retention

Build structured ride dataset for future intelligence



---

3. 👤 TARGET USERS

Core Users

Daily riders (commuters)

Motorcycle owners without reliable odometers


Secondary

Enthusiasts / touring riders

Delivery riders (future B2B)



---

4. 🧱 PLATFORM & TECH STACK

Frontend

Flutter (mandatory)

Single codebase → Android + iOS



Backend

Node.js / Django

REST API


Database

PostgreSQL


Realtime / Notifications

Firebase:

Auth

Push notifications



Maps

Google Maps integration


Sensors Used

GPS

Accelerometer

Gyroscope



---

5. 🎨 UI/UX DESIGN SYSTEM

🎨 Theme: Dark Blue Performance UI

Colors

Base

Background: #0B0D10

Surface: #12161B

Border: #1E242C


Primary (Blue)

Primary: #3B82F6

Highlight: #60A5FA


Accent (for alerts)

Orange: #FF6A00


Status

Success: #22C55E

Warning: #F59E0B

Danger: #EF4444



---

🔤 Typography

Font: Inter (or system default)

Large numeric displays for:

Speed

Distance


Small labels for context



---

🧩 UI Style Principles

Dashboard-style UI (not social-first)

Rounded corners: 12–16px

Minimal clutter

High contrast for sunlight readability

One-thumb usability



---

6. 📱 NAVIGATION STRUCTURE

Bottom Navigation (fixed):

1. Social


2. AI Chatbot


3. Record (default open)


4. Maintenance


5. Garage/Profile




---

7. 🧩 FEATURES & REQUIREMENTS


---

7.1 🏍️ MULTI-BIKE GARAGE

Features

Add multiple bikes:

Brand

Model

Year (optional)

Engine CC

Image upload


Select active bike

Per-bike stats:

Total distance

Ride count

Last ride date




---

7.2 🎥 RIDE RECORDING SYSTEM

Entry Screen

Full-screen map

Center: Press & Hold button


Behavior

Hold → start ride

Release → pause option

End → ride summary



---

Data Captured

Core

Timestamp

Latitude, Longitude

Speed (m/s)

Distance


Derived

Acceleration

Jerk (rate of change of acceleration)



---

7.3 📐 DATA CALCULATIONS

Speed

From GPS


---

Acceleration

a = \frac{v_2 - v_1}{t_2 - t_1}


---

🧠 Jerk (IMPORTANT REQUIREMENT)

j = \frac{a_2 - a_1}{t_2 - t_1}

Usage

Detect aggressive riding

Identify:

Sudden braking

Rapid throttle changes




---

Event Detection Rules

Hard Braking

Acceleration < threshold (e.g., -4 m/s²)


Rapid Acceleration

Acceleration > threshold (e.g., +4 m/s²)


High Jerk Event

Jerk exceeds threshold



---

7.4 📊 RIDE SUMMARY

Display

Map snapshot

Distance

Avg speed

Max speed

Duration


Metrics

Hard brakes count

Rapid acceleration count

High jerk events



---

7.5 🚨 REAL-TIME ALERTS

During ride:

Overspeed alert

Harsh braking alert

Fatigue alert (time-based)


UI:

Subtle flash + haptic feedback



---

7.6 🔧 MAINTENANCE SYSTEM

Tracking

Distance-based

Time-based


Rules (example)

Oil change: 1000–1500 km

Air filter: 8k–10k km (adjust for Dhaka conditions)


Features

Suggestions:

“Air filter check recommended”


Maintenance log

Cost tracking



---

7.7 🤖 AI CHATBOT

Capabilities

Maintenance advice

Ride explanation

General bike Q&A


Inputs

User query

Ride data



---

7.8 👥 SOCIAL (LIGHTWEIGHT)

Share ride summary

Follow users

Like/comment (optional)



---

8. 📊 DATA MODEL (SIMPLIFIED)

User

id

name

email


Bike

id

user_id

brand

model

cc

image_url


Ride

id

user_id

bike_id

start_time

end_time

distance

avg_speed

max_speed


RidePoint

ride_id

timestamp

lat

lng

speed

acceleration

jerk


Maintenance

bike_id

type

date

km



---

9. 🧪 USER STORIES


---

Onboarding

As a user, I want to add my bike so I can track rides for it.



---

Ride Tracking

As a user, I want to press and hold to start a ride so that it feels simple and fast.

As a user, I want to see live speed so I can monitor my riding.



---

Ride Insights

As a user, I want to see how aggressively I rode so I can improve.



---

Maintenance

As a user, I want reminders for oil change so I don’t damage my bike.



---

Multi-bike

As a user, I want multiple bikes so I can track each separately.



---

Social

As a user, I want to share rides so I can connect with friends.



---

10. ⚙️ PERFORMANCE REQUIREMENTS

Low battery consumption

Offline recording

Sync later

Fast app launch



---

11. 🗺️ ROADMAP

V1 (MVP)

Ride tracking

Multi-bike

Summary

Maintenance


V2

Alerts

Shareable cards

Chatbot


V3

Social

Advanced insights



---

12. ⚠️ RISKS

Battery drain

GPS inaccuracies

Overcomplex UI



---

13. ✅ SUCCESS METRICS

DAU

Rides per user

Retention (7-day, 30-day)



---

🔥 FINAL PRODUCT PRINCIPLE

ThrottleIQ must feel like:

> A smart riding companion + machine memory system



Not:

> Just another tracking app




---