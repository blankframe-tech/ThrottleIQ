# P7 - POI Directory Implementation Summary

## Overview
P7 adds a rider-facing POI (Point of Interest) Directory to ThrottleIQ, enabling riders to discover and rate fuel stations, garages, and parts shops with admin-verified place listings, geohash-based mapping, and photo/review capabilities.

## Files Created

### Data Models & Entities
1. **lib/features/poi_directory/domain/entities/place_entity.dart**
   - `PlaceEntity`: Core entity for POI locations
   - `PlaceCategory`: Enum (fuel, garage, parts) with display names and icons
   - Properties: id, name, category, coordinates, geohash, address, phone, hours, photos, verified flag, creator, timestamps, rating aggregates

2. **lib/features/poi_directory/domain/entities/review_entity.dart**
   - `ReviewEntity`: User reviews for places
   - Properties: id, placeId, userId, rating (1-5 stars), text, images, createdAt, flagged status

### Data Models (Firestore Mapping)
3. **lib/features/poi_directory/data/models/place_model.dart**
   - Converts between `PlaceEntity` and Firestore documents
   - Handles `PlaceCategory` string serialization
   - Includes `copyWith()` for immutability

4. **lib/features/poi_directory/data/models/review_model.dart**
   - Converts between `ReviewEntity` and Firestore documents
   - Timestamp handling via Firestore `Timestamp`
   - Includes `copyWith()` for immutability

### Repositories (Data Access Layer)
5. **lib/features/poi_directory/data/repositories/place_repository.dart**
   - `PlaceRepository`: CRUD operations for places
   - Key methods:
     - `addPlace()`: Create new POI
     - `getPlace()`: Fetch by ID
     - `getPlacesByCategory()`: Filter by category
     - `getPlacesByGeohash()`: Geospatial query for viewport
     - `getNearbyPlaces()`: Distance-based search with sorting
     - `updateVerification()`: Admin verification (protected)
     - `updatePlaceRating()`: Update aggregated ratings
   - Includes Haversine distance calculation for proximity sorting

6. **lib/features/poi_directory/data/repositories/review_repository.dart**
   - `ReviewRepository`: CRUD for reviews
   - Key methods:
     - `addReview()`: Submit a review
     - `getUserReviewId()`: One-per-user constraint enforcement
     - `updateReview()`: Edit existing review
     - `getReviewsForPlace()`: Fetch all reviews for a POI
     - `getPlaceRatingStats()`: Calculate average rating and distribution
     - `streamReviewsForPlace()`: Real-time updates
     - `flagReview()`: Report inappropriate content
     - `getFlaggedReviews()`: Admin moderation queue

### Utilities
7. **lib/features/poi_directory/data/utils/geohash_utils.dart**
   - `GeohashUtils`: Geospatial query helpers
   - Methods:
     - `encode()`: Generate geohash from lat/lng
     - `decode()`: Get bounding box from geohash
     - `getGeohashesForViewport()`: Generate grid of geohashes covering map viewport
     - `simplifyGeohashes()`: Remove redundant prefix overlaps
     - `calculateDistance()`: Haversine formula for great-circle distance
     - `isWithinBounds()`: Viewport containment check
   - Uses `geohash` package for core operations

8. **lib/features/poi_directory/data/utils/image_compression_utils.dart**
   - `ImageCompressionUtils`: Photo compression and validation
   - Constants: `maxFileSizeBytes = 2MB`
   - Methods:
     - `compressImage()`: File → compress → temp file (max width 1280px, quality 85→50)
     - `compressImageFromBytes()`: Byte stream compression
     - `compressImages()`: Batch processing
     - `getFileSizeMB()`: Size calculation
     - `isFileSizeValid()`: Size validation
     - `getImageDimensions()`: Extract width/height
   - Uses `image` package for processing

### Security & Firestore Rules
9. **firestore_rules_poi_directory.txt**
   - Read-only for authenticated users
   - Create: Authenticated users (auto-set createdBy/timestamp, verified=false)
   - Update: Owner can edit (except verified), admin can set verified flag
   - Delete: Owner or admin
   - Review rules: Similar, plus flagging (admin-only)
   - Enforces admin claim check for verification
   - Document validation on write

### Tests
10. **test/features/poi_directory/data/repositories/place_repository_test.dart**
    - Tests CRUD operations
    - Tests geohash-based queries
    - Tests distance calculations
    - Tests rating aggregation (average, zero-review edge case)
    - Tests model conversions (Entity ↔ Firestore)

11. **test/features/poi_directory/data/utils/geohash_utils_test.dart**
    - Tests geohash encoding/decoding consistency
    - Tests viewport coverage generation
    - Tests distance calculations (Dhaka↔Chittagong ~261km reference)
    - Tests bounds validation
    - Tests precision levels (hash length)
    - Tests geohash simplification

12. **test/features/poi_directory/data/repositories/review_repository_test.dart**
    - Tests review entity creation and equality
    - Tests rating aggregation (average from list)
    - Tests rating distribution (1-5 star breakdown)
    - Tests flagging logic
    - Tests validation (stars 1-5, image URLs, etc.)

13. **test/features/poi_directory/data/utils/image_compression_utils_test.dart**
    - Tests file size constants (2MB)
    - Tests size validation logic
    - Tests dimension constraints (1280px max width)
    - Tests aspect ratio preservation
    - Tests quality reduction strategy (85→50 in 5-step increments)
    - Tests compression loop until size limit

## Dependencies Added to pubspec.yaml
```yaml
# Image
image: ^4.1.0
firebase_storage: ^11.6.0

# Geolocation & Geohashing
geoflutterfire_plus: ^0.8.4
geohash: ^0.13.0
```

## Architecture Overview

### Data Flow
1. **Place Discovery** → Geohash query → `PlaceRepository.getPlacesByGeohash()` → List/Map display
2. **Rating** → Review submission → `ReviewRepository.addReview()` → Firestore trigger → `PlaceRepository.updatePlaceRating()`
3. **Admin Action** → Verification → `PlaceRepository.updateVerification()` (admin-guarded)

### Firestore Collections
- `/places/{placeId}`: Place documents with rating aggregates
  - Indexes: `{geohash, verified}`, `{category, verified}`
- `/reviews/{reviewId}`: Review documents (one per user per place)
  - Indexes: `{placeId, createdAt desc}`, `{userId, createdAt desc}`, `{flagged}`
- `/places/{placeId}/reviews/{reviewId}` (optional subcollection for consistency)

### Geohash Query Strategy
- Map viewport bounds → Grid of geohashes (precision ~6 for ~1km squares)
- Query each geohash prefix: `where('geohash', >= prefix, < prefix+'~')`
- Combine results, deduplicate by ID
- Sort by distance from user center
- Optional: Simplify overlapping prefixes to reduce queries

### Image Upload Flow
1. User picks image (camera/gallery) via `image_picker`
2. `ImageCompressionUtils.compressImage()` → File
3. Upload to `firebase_storage` at `/places/{placeId}/photos/{uuid}.jpg`
4. Store URL in place/review document

## UI Screens to Implement (Not in this commit)

### 1. Explore Tab (`explore_screen.dart`)
- Top: Map view (using `flutter_map`)
  - Markers for places by category color
  - Tap to show quick preview (name, rating, distance)
- Bottom: Filterable list with chips
  - Filter: ⛽ Fuel | 🔧 Garage | 🛒 Parts
  - Sort: Distance | Rating | Newest
  - LazyList with pagination

### 2. Place Detail Screen (`place_detail_screen.dart`)
- Header: Photo carousel (right-swipe ↔), verified ✓ badge
- Info block: Name, category icon, address, phone (tap→call), hours
- Rating summary: ★★★★☆ (4.0/5) · 23 reviews
- Rating breakdown: Bars for 1-5 stars with counts
- Reviews section: List of reviews (recent first), each with:
  - Reviewer name, date, stars, text, images
  - Report/Flag button (with reason picker)
  - Own reviews show Edit/Delete
- CTA buttons:
  - 📞 Call
  - 🗺️ Directions (Maps)
  - ➕ Add Review (if user hasn't rated)
- FAB: Share place (Share+ with link)

### 3. Add Place Screen (`add_place_screen.dart`)
- Current location map + pin-drop UX
- Form:
  - Name field
  - Category dropdown
  - Address (geocoded from pin)
  - Phone (optional, masked)
  - Hours (optional, time picker)
  - Photo gallery button (multi-select)
- Validation: Name + category required, max 3 photos
- Submit: Create place, upload photos, show "Added!" toast

### 4. Add/Edit Review Screen (`review_form_screen.dart`)
- Photo carousel (pick up to 4 images)
- Star rating picker (tap ★)
- Text input (max 500 chars, character count)
- Submit button (validates stars + text)
- Optimistic UI: Show review immediately, sync in background

### 5. Map Widget (`poi_map_widget.dart`)
- Manages `flutter_map` with `FlutterMapController`
- Geohash query on viewport change (debounced)
- Marker layer: Category → icon/color mapping
- Tap → show preview card
- Current location circle
- Zoom level threshold (only fetch if zoom ≥ 13)

## Integration Checklist

### Backend Setup
- [ ] Add Firestore indexes:
  - `places`: {geohash, verified}, {category, verified}
  - `reviews`: {placeId, createdAt desc}, {userId, createdAt desc}, {flagged}
- [ ] Deploy Firestore rules from `firestore_rules_poi_directory.txt`
- [ ] Set up Firebase Storage bucket with `/places/{placeId}/photos/` folder rule
- [ ] Create admin custom claims setup in `auth_provider.dart` or Cloud Functions

### Frontend Integration
- [ ] Wire `PlaceRepository` + `ReviewRepository` into Riverpod providers
- [ ] Add route `/explore` (tab) and `/place/{id}` (detail) to `app_router.dart`
- [ ] Create Riverpod providers:
  - `placesProvider(category?, nearbyKm?)` → List<Place>
  - `placeDetailProvider(id)` → Place + reviews stream
  - `userReviewProvider(placeId)` → Review?
  - `addPlaceProvider` → FutureProvider<void>
- [ ] Add "Explore" tab to main app shell (alongside Rides, Garage, etc.)
- [ ] Integrate with `geolocator` for current location (already a dependency)
- [ ] Add image picker + compression to flow
- [ ] Update Firebase Storage rules for public read + authenticated write

### Testing
- [ ] Run unit tests: `flutter test test/features/poi_directory/`
- [ ] Integration test: Mock Firestore + verify full CRUD
- [ ] E2E test: Real Firebase dev project (dry run)
- [ ] Manual: Add place → rate → verify as admin

## Security Considerations
- ✅ Admin verification enforced at Firestore rule level (custom claim check)
- ✅ One-review-per-user keyed by `userId_placeId` (enforce in app + via unique index if needed)
- ✅ Image size limits (2MB) + type validation (JPEG/PNG only)
- ⚠️ TODO: Content moderation (filter flagged reviews from display; only show if unflagged)
- ⚠️ TODO: Rate limiting on add/review/flag (Cloud Functions)
- ⚠️ TODO: Spam detection (duplicate places, review bombing)

## Performance Notes
- Geohash queries are efficient (index on `geohash` field)
- Rating aggregation (`ratingSum`, `ratingCount`) avoids sub-collection reads
- Images compressed client-side before upload (2MB target)
- Lazy-load reviews (paginate after 10)
- Stream reviews for real-time updates without polling

## Next Steps (Future Phases)
1. **P7a**: Admin moderation dashboard (flag queue, place editing)
2. **P7b**: Advanced filters (price range, services offered, open now)
3. **P7c**: Navigation integration (in-ride "nearest fuel" quick action)
4. **P7d**: User reputation (helpfulness voting on reviews, reviewer badges)
5. **P7e**: Offline sync (cache nearby places, work when offline)

## References
- Geohash docs: https://github.com/davisching/geohash-dart
- Firebase Firestore best practices: https://firebase.google.com/docs/firestore/best-practices
- Flutter Map: https://github.com/fleaflet/flutter_map
- Image compression: https://pub.dev/packages/image
