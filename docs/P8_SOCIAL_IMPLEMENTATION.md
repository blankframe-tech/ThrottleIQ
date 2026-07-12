# P8 Social Features Implementation

This document describes the implementation of P8 (Social: feed, shared routes, group rides) for ThrottleIQ.

## Overview

P8 introduces social features that enable riders to share rides, save routes, join group rides, and participate in challenges. All features prioritize **privacy and security**, with automatic privacy zone stripping on shared rides.

## Architecture

### Core Components

#### 1. Privacy Zone Clipper
**File**: `domain/utilities/privacy_zone_clipper.dart`

Implements automatic privacy zone protection:
- Strips first ~200m from polyline (prevents home location leaks)
- Strips last ~200m from polyline (prevents destination leaks)
- Uses Haversine distance calculation for accurate geographic measurement
- Applied automatically when sharing rides

**Key Methods**:
- `clipPolyline(polyline)` - Main method that clips both ends
- `_haversineDistance()` - Calculates distance between two coordinates

**Testing**: `test/features/social/privacy_zone_clipper_test.dart`

#### 2. Data Models

**SharedRideEntity** - Represents a shared ride
- User & bike information
- Ride statistics (distance, duration, max speed)
- Privacy settings (public/private, allowed users)
- Like count and comment count
- Clipped polyline for map display
- Optional reference to saved route

**RouteEntity** - Represents a saved route
- Route name and description
- Polyline and distance
- Usage tracking (times ridden)
- Privacy settings (public/shared)
- Map snapshot URL

**GroupRideEntity** - Represents a group ride session
- Creator information
- Start time and status (planned/active/completed)
- Member list with status (joined/pending/declined)
- Optional route reference
- Maximum participant limit

**ChallengeEntity** - Represents a monthly challenge
- Type (distance or streak)
- Target value (km or days)
- Start/end dates
- Badge ID
- User progress tracking

**RideCommentEntity** - Represents comments on shared rides
- Comment text
- Author information
- Timestamp

### 3. Repositories

#### RideShareRepository
**File**: `data/repositories/ride_share_repository.dart`

Manages shared ride lifecycle:
- `shareRide()` - Shares a ride with privacy zone clipping
- `getSharedRide()` - Retrieves a single ride
- `getFriendsFeed()` - Gets paginated feed of friends' rides
- `getPublicRides()` - Gets public rides for discovery
- `toggleLike()` - Like/unlike a ride
- `addComment()` / `getComments()` - Comment management
- `deleteSharedRide()` - Deletes ride and all data
- `updateRideVisibility()` - Changes privacy settings

**Firestore Structure**:
```
rides/{rideId}
  - ride data (with clipped polyline)
  - likes/{userId}
  - comments/{commentId}
```

#### RouteRepository
**File**: `data/repositories/route_repository.dart`

Manages saved routes:
- `saveRoute()` - Saves a ride as a reusable route
- `getRoute()` - Gets a specific route
- `getUserRoutes()` - Lists user's routes
- `getPublicRoutes()` - Lists public routes for discovery
- `shareRoute()` - Shares route with specific users
- `makePublic()` - Makes route publicly discoverable
- `incrementTimesRidden()` - Updates usage statistics
- `deleteRoute()` - Deletes a route
- `updateRoute()` - Updates route metadata

**Firestore Structure**:
```
users/{userId}/routes/{routeId}
  - route data (polyline, metadata)
```

#### GroupRideRepository
**File**: `data/repositories/group_ride_repository.dart`

Manages group rides:
- `createGroupRide()` - Creates new group ride
- `getGroupRide()` - Retrieves group ride details
- `getUpcomingGroupRides()` - Lists upcoming rides
- `getUserGroupRides()` - Lists rides created by user
- `inviteUsers()` - Sends invitations
- `acceptInvitation()` / `declineInvitation()` - Invitation management
- `updateMemberLocation()` - Updates member's live position
- `getMemberLocations()` / `streamMemberLocations()` - Gets/streams locations
- `startGroupRide()` / `endGroupRide()` - Lifecycle management
- `removeMember()` - Removes member from ride
- `deleteGroupRide()` - Deletes ride

**Firestore Structure**:
```
groupRides/{groupRideId}
  - group ride data
  - invitations/{userId}
  - memberLocations/{userId}
```

**Live Location Updates**:
- Update frequency: Every 10 seconds during active rides
- Stored in real-time subcollection
- Streams available for live map
- Regroup alert triggered when member > 5km behind

#### ChallengeRepository
**File**: `data/repositories/challenge_repository.dart`

Manages challenges and badges:
- `getActiveChallenges()` - Gets current month's challenges
- `getChallenge()` - Gets specific challenge
- `getUserProgress()` - Gets user's progress on all challenges
- `getUserChallengeProgress()` - Gets progress on one challenge
- `updateChallengeProgress()` - Updates progress value
- `earnBadge()` - Awards badge to user
- `getEarnedBadges()` - Lists user's earned badges
- `createChallenge()` - Creates new challenge (admin)
- `seedMonthlyChallenges()` - Seeds monthly challenges

**Firestore Structure**:
```
challenges/{challengeId}
  - challenge metadata

users/{userId}/challengeProgress/{challengeId}
  - progress data (current value, completed status)

users/{userId}/earnedBadges/{badgeId}
  - badge data (earned timestamp)
```

**Challenge Types**:
- Distance: "Ride X km in the month"
- Streak: "Ride for X consecutive days"

### 4. Models (Data Layer)

Each entity has a corresponding model for Firestore serialization:
- `RideShareModel` - Serializes SharedRideEntity
- `RouteModel` - Serializes RouteEntity
- `GroupRideModel` / `GroupRideMemberModel` - Serialize GroupRideEntity
- `ChallengeModel` / `UserChallengeProgressModel` - Serialize challenge data

**Polyline Serialization**:
All polylines are serialized as:
```json
"polyline": [
  {"lat": 40.7128, "lng": -74.0060},
  {"lat": 40.7200, "lng": -74.0100}
]
```

### 5. Presentation Screens

#### FeedScreen
**File**: `presentation/screens/feed_screen.dart`

Home tab showing friend rides:
- Chronological feed of friends' shared rides
- Ride cards with thumbnails
- Like/kudos button
- Pagination support
- Tap to view details

#### RideDetailScreen
**File**: `presentation/screens/ride_detail_screen.dart`

Full ride view:
- Map with full polyline (unclipped)
- Ride statistics (distance, duration, speeds)
- Comments section
- Like button
- Delete button (for ride owner)

#### RouteListScreen
**File**: `presentation/screens/route_list_screen.dart`

Saved routes management:
- List of personal saved routes
- Route details (distance, times ridden)
- Re-ride button (loads route on map)
- Share route functionality
- Public route discovery
- Delete route option

#### GroupRideMapScreen
**File**: `presentation/screens/group_ride_map_screen.dart`

Live group ride tracking:
- Live map showing all member positions
- Member list with names and distances
- Regroup alerts (>5km behind)
- Ride control (start/end)
- Member status indicators
- Real-time position updates

## Data Flow

### Sharing a Ride
1. User completes ride and selects "Share"
2. Ride presenter calls `RideShareRepository.shareRide()`
3. Privacy zone clipper removes first/last 200m
4. Clipped polyline uploaded to Firestore under `/rides/{rideId}`
5. Ride appears in friends' feeds via `getFriendsFeed()`

### Saving a Route
1. User completes ride and selects "Save as Route"
2. `RouteRepository.saveRoute()` creates route document
3. Route name and description are stored
4. Route can be shared or made public
5. Usage counter incremented when route is ridden again

### Group Ride Session
1. Creator calls `GroupRideRepository.createGroupRide()`
2. Members invited via `inviteUsers()`
3. Members accept invitation via `acceptInvitation()`
4. During active ride:
   - Member locations updated every 10s via `updateMemberLocation()`
   - Live map streams locations via `streamMemberLocations()`
   - Regroup alerts triggered when distance > 5km
5. Creator ends ride via `endGroupRide()`

### Challenges
1. Admin seeds monthly challenges via `seedMonthlyChallenges()`
2. Challenges appear via `getActiveChallenges()`
3. User progress tracked automatically from ride data
4. When target reached, `earnBadge()` awards badge
5. Badges sync to cloud and display in profile

## Privacy & Security

### Privacy Zone Implementation
- **Automatic**: Always applied when sharing
- **Distance**: ~200m (configurable via constant)
- **Bidirectional**: Clips both start and end
- **Calculation**: Uses Haversine formula for accuracy
- **Result**: Home and destination locations never exposed

### Sharing Controls
- Rides can be public or private
- Private rides limited to specific users
- Rider can change visibility after sharing
- Rider can delete shared ride at any time
- Comments moderated by ride owner

### Data Isolation
- Friend relationships needed to access friend feed
- Public rides discoverable but read-only
- Own rides editable and deletable
- Group rides limited to invited members

## Testing

### Unit Tests
- **privacy_zone_clipper_test.dart** - Privacy zone clipping logic
- **shared_ride_entity_test.dart** - SharedRideEntity behavior
- **challenge_entity_test.dart** - Challenge entity operations
- **route_entity_test.dart** - Route entity operations
- **group_ride_entity_test.dart** - Group ride entity behavior
- **ride_share_model_test.dart** - Model serialization/deserialization

### Test Coverage
- Privacy zone clipping (short rides, distance calculation)
- Entity equality and copying
- Model conversion to/from Firestore
- Challenge progress tracking
- Group ride member management

## Future Enhancements

### Phase 2 (Not Implemented)
1. Real-time notifications for ride shares
2. Leaderboards (monthly, all-time)
3. Custom challenge creation
4. Route difficulty ratings
5. Social profiles with activity history
6. Ride recommendations
7. Integration with strava-style segments
8. Voice notifications during group rides

### Phase 3 (Not Implemented)
1. Advanced analytics dashboard
2. Ride filtering and search
3. Achievement system
4. Social messaging between riders
5. Event organization
6. Ride sponsorships/rewards

## Database Schema Reference

### Rides Collection
```typescript
interface SharedRide {
  id: string;
  userId: string;
  userName: string;
  userPhotoUrl: string;
  bikeId: string;
  bikeName: string;
  bikeType: string;
  rideDate: Timestamp;
  distanceKm: number;
  durationSeconds: number;
  maxSpeedKmh: number;
  polyline: Array<{lat: number; lng: number}>;
  mapSnapshotUrl?: string;
  likes: number;
  comments: number;
  createdAt: Timestamp;
  isPrivate: boolean;
  allowedUserIds: string[];
  routeId?: string;
}
```

### Group Rides Collection
```typescript
interface GroupRide {
  id: string;
  creatorId: string;
  creatorName: string;
  name: string;
  description?: string;
  startTime: Timestamp;
  routeId?: string;
  status: 'planned' | 'active' | 'completed';
  members: Array<{
    userId: string;
    userName: string;
    userPhotoUrl: string;
    joinedAt: Timestamp;
    status: 'joined' | 'pending' | 'declined';
    currentLat?: number;
    currentLng?: number;
  }>;
  createdAt: Timestamp;
  maxParticipants: number;
}
```

## Configuration

### Privacy Zone Distance
```dart
static const double privacyZoneDistanceMeters = 200.0;
```

### Group Ride Constraints
```dart
- Max participants: 20 (configurable per ride)
- Location update frequency: 10 seconds
- Regroup alert threshold: 5 km
```

### Challenge Defaults
```dart
- Monthly distance challenge: 500 km
- Weekly streak challenge: 7 days
- Auto-seeded monthly
```

## Dependencies

No new dependencies added. Implementation uses:
- `cloud_firestore` - Firestore integration
- `latlong2` - Geographic coordinate handling
- `flutter_riverpod` - State management (future)
- Existing ThrottleIQ structure

## Migration Notes

For existing riders:
1. No breaking changes to ride history
2. Historical rides can be shared (with clipping)
3. Privacy settings default to public (can be changed)
4. Routes auto-created from first 3 completed rides (future enhancement)
5. Challenge progress calculated retroactively
