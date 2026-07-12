# P5: Cloud Sync & Export Implementation

## Overview
P5 implements automatic cloud synchronization of ride data to Firestore and provides export functionality for rides in JSON and GPX formats.

## Features Implemented

### 1. Firestore Integration
- **Cloud Repository**: Manages all Firestore operations
  - `uploadRides()`: Syncs ride data to Firestore `/users/{uid}/rides`
  - `uploadBikes()`: Syncs bike data to Firestore `/users/{uid}/bikes`
  - `uploadMaintenance()`: Syncs maintenance logs to Firestore `/users/{uid}/maintenance`
  - `updateUserProfile()`: Stores user display name and photo URL
  - `getUserProfile()`: Retrieves user profile from Firestore

### 2. Automatic Sync Manager
- **SyncManager Provider**: Handles background synchronization
  - Auto-sync on app resume
  - Periodic sync every 5 minutes when online
  - Offline-safe: Queues syncs when no internet, retries on reconnect
  - Connectivity detection using `connectivity_plus` package
  - Retry logic with exponential backoff
  - Status tracking: idle, syncing, success, failure

### 3. Data Export
- **JSON Export**: Full ride data including:
  - Ride metadata (distance, duration, speeds)
  - Event counts (hard brakes, rapid acceleration, jerk events)
  - Complete polyline points with timestamps
  - Export timestamp

- **GPX Export**: Standard GPS exchange format
  - Valid GPX 1.1 XML structure
  - Includes track segment with lat/lng/elevation for each point
  - Proper bounds calculation (min/max coordinates)
  - Compatible with most mapping applications (Google Maps, Strava, etc.)

### 4. User Profile Setup
- **Onboarding Enhancement**:
  - Step 1: Capture user's display name
  - Step 2: Add first bike
  - Profile data stored locally in SQLite
  - Profile synced to Firestore for cross-device access

### 5. Database Updates
- **user_profiles Table**: New table for storing user information
  - uid: User's Firebase UID
  - display_name: User's full name
  - photo_url: Profile picture URL (optional)
  - created_at/updated_at: Timestamps

- **Synced Flag**: Existing `synced` column (0=unsynced, 1=synced) in rides, bikes, and maintenance tables

## Architecture

### CloudRepository (`lib/core/cloud/cloud_repository.dart`)
```dart
class CloudRepository {
  // Firestore uploads with local DB sync
  Future<void> uploadRides(String uid, List<Map> rides)
  Future<void> uploadBikes(String uid, List<Map> bikes)
  Future<void> uploadMaintenance(String uid, List<Map> logs)
  
  // User profile management
  Future<void> updateUserProfile(String uid, String displayName, String? photoUrl)
  Future<Map?> getUserProfile(String uid)
  
  // Export functionality
  Future<File> exportToJSON(Map ride, List<Map> ridePoints)
  Future<File> exportToGPX(Map ride, List<Map> ridePoints)
}
```

### SyncManager (`lib/core/cloud/sync_manager.dart`)
```dart
class SyncManager {
  // Start/stop auto-sync
  void startAutoSync()
  void stopAutoSync()
  
  // Manual sync
  Future<void> sync()
  
  // Status tracking
  SyncStatus get status
  bool get isSyncing
}
```

### ExportService (`lib/core/cloud/export_service.dart`)
```dart
class ExportService {
  // Export to files
  Future<File?> exportRideToJSON(Map ride)
  Future<File?> exportRideToGPX(Map ride)
  
  // Utilities
  Future<String?> getDownloadsPath()
}
```

## Firestore Security Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User data - only accessible to the owner
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
      
      match /rides/{rideId} {
        allow read, write: if request.auth.uid == uid;
      }
      
      match /bikes/{bikeId} {
        allow read, write: if request.auth.uid == uid;
      }
      
      match /maintenance/{maintenanceId} {
        allow read, write: if request.auth.uid == uid;
      }
    }
  }
}
```

## Dependencies Added
- `cloud_firestore: ^4.14.0` - Firestore database
- `path_provider: ^2.1.1` - Access to Downloads folder

## Usage Examples

### Start Auto-Sync
```dart
final syncManager = ref.watch(syncManagerProvider);
syncManager.startAutoSync();
```

### Monitor Sync Status
```dart
final syncStatus = ref.watch(syncStatusProvider);
final isSyncing = ref.watch(isSyncingProvider);

if (isSyncing) {
  // Show loading indicator
}
```

### Export Ride
```dart
final exportService = ref.watch(exportServiceProvider);

// Export as JSON
final jsonFile = await exportService.exportRideToJSON(rideData);

// Export as GPX
final gpxFile = await exportService.exportRideToGPX(rideData);
```

### Save User Profile
```dart
await cloudRepository.updateUserProfile(
  uid: currentUser.uid,
  displayName: 'John Doe',
  photoUrl: 'https://example.com/photo.jpg'
);
```

## Testing

### Test Coverage
- SyncManager tests: Connectivity detection, retry logic, duplicate prevention
- CloudRepository tests: Firestore uploads, local DB sync, batch operations
- ExportService tests: JSON/GPX generation, file creation, validation
- UserProfile tests: Local storage, Firestore sync, profile updates

### Mock Firestore
Tests use Mockito to mock Firestore without real Firebase:
```dart
class MockCloudFirestore extends Mock implements FirebaseFirestore {}
```

## Mock Mode Support
When `TIPSOI_MOCK=1`:
- Sync operations are skipped
- Exports still work with mock data
- No Firestore connections attempted

## File Locations
- Exported files are saved to device's Downloads folder
- File naming: `ride_{rideId}_{timestamp}.{json|gpx}`
- Example: `ride_abc123_1689456789.gpx`

## Error Handling
- Graceful handling of offline scenarios
- Automatic retry on connection failure
- User-friendly error messages
- Fallback to local data if Firestore unavailable

## Future Enhancements
1. Batch export (multiple rides at once)
2. Cloud backup/restore functionality
3. Ride sharing via shared Firestore documents
4. Offline map tile caching
5. Device sync across multiple phones
6. Photo attachments in ride data
7. Real-time sync using Firestore listeners

## Development Notes
- All exports use ISO 8601 timestamps
- GPX files are compatible with all major mapping applications
- Synced flag is transaction-safe
- Cloud operations are non-blocking (async/await)
- No PII is logged during sync operations
