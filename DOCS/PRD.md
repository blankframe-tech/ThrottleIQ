# Product Requirements Document

## 1. Introduction
This document gives the requirements for ThrottleIQ.
ThrottleIQ is an application for motorcycle riders.
The application records data during a motorcycle ride.
It uses the sensors of a smartphone.

## 2. Main Features

### 2.1. Ride Recording
The application must record the route of the motorcycle.
It must record the speed and acceleration of the motorcycle.
The application uses the GPS of the smartphone.
It also uses the accelerometer and the gyroscope.
The background service must operate when the screen is off.

### 2.2. Ride Analysis
The application must analyze the recorded data.
It must calculate the lean angle of the motorcycle.
It must calculate the maximum speed.
The application must show the data to the rider.

### 2.3. Safety
The application must detect a crash.
If a crash occurs, the application must send an alert.
The alert must go to emergency contacts.
The rider can stop the alert within one minute.

### 2.4. Garage and Maintenance
The rider can add motorcycles to the garage.
The application must track the maintenance schedule.
It must remind the rider when service is necessary.
The rider can log maintenance tasks.

### 2.5. Social and Community
The rider can share a ride with friends.
The application must have a forum for riders.
Riders can see the locations of friends during a group ride.

## 3. System Architecture
The system has a mobile application and a cloud backend.
The mobile application uses the Flutter framework.
The application saves data in a local SQLite database.
The cloud backend uses Firebase services.
The application synchronizes local data with the cloud database.

## 4. Security and Privacy
The rider owns their data.
The application must encrypt passwords.
The application must not share location data without permission.
