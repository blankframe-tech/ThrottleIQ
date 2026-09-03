import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ride/presentation/providers/ride_recording_provider.dart';
import '../../data/repositories/review_repository.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/place_directions.dart';
import '../providers/places_provider.dart';

/// Place info header + reviews list + "Add your review" (star picker + text).
///
/// Submitting a review writes the new review doc, then recomputes the
/// place's ratingSum/ratingCount (`ReviewRepository.addReviewAndUpdatePlaceRating`)
/// — see that method's doc comment for why those are two sequential writes
/// rather than one atomic transaction (the places/{placeId} security rule
/// needs the review to already exist to authorize the rating bump).
class PlaceDetailScreen extends ConsumerStatefulWidget {
  final String placeId;
  const PlaceDetailScreen({super.key, required this.placeId});

  @override
  ConsumerState<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends ConsumerState<PlaceDetailScreen> {
  int _selectedStars = 5;
  final _reviewController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview(PlaceEntity place) async {
    final text = _reviewController.text.trim();
    final user = ref.read(currentUserProvider);
    if (user == null || text.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    try {
      final reviewRepository = ReviewRepository();

      // One review per user per place. This is now enforced server-side
      // regardless of what the client does: review doc ids are
      // deterministic (`{uid}_{placeId}`, see ReviewRepository), and the
      // reviews/{reviewId} security rule grants no `update`, so a second
      // submission is rejected by Firestore outright. getUserReviewId is
      // kept as a fast-path client-side check purely for UX — it shows the
      // "already reviewed" message immediately instead of waiting on a
      // round-trip permission-denied error from Firestore.
      final existingReviewId =
          await reviewRepository.getUserReviewId(place.id, user.uid);
      if (existingReviewId != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You've already reviewed this place.")),
          );
        }
        return;
      }

      final review = ReviewEntity(
        id: '', // ReviewRepository derives the real (deterministic) id.
        placeId: place.id,
        userId: user.uid,
        stars: _selectedStars,
        text: text,
        createdAt: DateTime.now(),
      );

      await reviewRepository.addReviewAndUpdatePlaceRating(review: review);

      // placeDetailProvider is now a live stream of the place doc, so the
      // header picks up the new rating aggregate on its own — only the
      // Places tab's one-shot list needs an explicit refresh.
      ref.invalidate(nearbyPlacesProvider);

      _reviewController.clear();
      if (mounted) setState(() => _selectedStars = 5);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit review: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeAsync = ref.watch(placeDetailProvider(widget.placeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(placeAsync.valueOrNull?.name ?? 'Place')),
      body: placeAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) =>
            Center(child: Text('$e', style: TextStyle(color: AppColors.danger))),
        data: (place) {
          if (place == null) {
            return Center(
              child: Text('Place not found', style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return _PlaceDetailBody(
            place: place,
            selectedStars: _selectedStars,
            onStarsChanged: (v) => setState(() => _selectedStars = v),
            reviewController: _reviewController,
            submitting: _submitting,
            onSubmit: () => _submitReview(place),
          );
        },
      ),
    );
  }
}

class _PlaceDetailBody extends ConsumerWidget {
  final PlaceEntity place;
  final int selectedStars;
  final ValueChanged<int> onStarsChanged;
  final TextEditingController reviewController;
  final bool submitting;
  final VoidCallback onSubmit;

  const _PlaceDetailBody({
    required this.place,
    required this.selectedStars,
    required this.onStarsChanged,
    required this.reviewController,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsForPlaceProvider(place.id));
    final uid = ref.watch(currentUserProvider)?.uid;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      children: [
        _PlaceHeader(place: place),
        const SizedBox(height: 24),
        Text(
          'Add your review',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 1; i <= 5; i++)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => onStarsChanged(i),
                icon: Icon(
                  i <= selectedStars ? Icons.star : Icons.star_border,
                  color: AppColors.warning,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: reviewController,
          maxLines: 3,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Share your experience...'),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: reviewController,
          builder: (context, value, _) {
            final canSubmit =
                uid != null && !submitting && value.text.trim().isNotEmpty;
            return ElevatedButton(
              onPressed: canSubmit ? onSubmit : null,
              child: submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit review'),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Reviews',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        reviewsAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Text('$e', style: TextStyle(color: AppColors.danger)),
          data: (reviews) {
            if (reviews.isEmpty) {
              return Text(
                'No reviews yet — be the first!',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              );
            }
            return Column(
              children: [
                for (final review in reviews) ...[
                  _ReviewTile(review: review, isOwn: review.userId == uid),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PlaceHeader extends StatelessWidget {
  final PlaceEntity place;
  const _PlaceHeader({required this.place});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(place.category.icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(place.category.displayName,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 16, color: AppColors.warning),
                      const SizedBox(width: 2),
                      Text(
                        place.ratingCount == 0 ? '—' : place.averageRating.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  Text(
                    '${place.ratingCount} review${place.ratingCount == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          // Address is optional on submission (and absent on Overpass imports
          // with no addr:* tags), so an empty one is normal — skip the row
          // entirely rather than rendering a lone pin icon beside blank text.
          if (place.address.trim().isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(place.address,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ),
              ],
            ),
          if (place.phone != null && place.phone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(place.phone!, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ],
          if (place.hours != null && place.hours!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(place.hours!, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _PlaceActions(place: place),
        ],
      ),
    );
  }
}

/// "Directions" (and "Call", when the place has a number) under the details.
///
/// Directions is the primary action — for a petrol pump or a garage, getting
/// there is the whole reason the rider opened this screen, so it's a filled
/// button at full width rather than an icon in the app bar.
class _PlaceActions extends ConsumerWidget {
  final PlaceEntity place;
  const _PlaceActions({required this.place});

  /// Opens the rider's maps app at driving directions to this place.
  ///
  /// `LaunchMode.externalApplication` matters: the default mode can open the
  /// link in an in-app webview on Android, which produces a *map of the route*
  /// with no live guidance — the opposite of what "Directions" promises. This
  /// forces the real Google Maps app (or the browser if it isn't installed).
  ///
  /// On iOS, if that fails outright we retry with Apple Maps, which is always
  /// present. A failure on either is reported rather than swallowed: a button
  /// that silently does nothing is worse than one that says why.
  Future<void> _openDirections(BuildContext context, WidgetRef ref) async {
    // Started *before* handing off to the external app, not after: once
    // launchUrl backgrounds ThrottleIQ, there is no foreground window left for
    // a location-permission prompt to appear in. Silently no-ops (see
    // RideRecordingNotifier.startRide) if a ride is already active/paused, if
    // there's no bike, or if permission is missing — a rider who only wanted
    // directions should never see an error from the ride the tap also
    // started.
    unawaited(ref.read(rideRecordingProvider.notifier).startRide());

    final google = googleMapsDirectionsUri(
      latitude: place.latitude,
      longitude: place.longitude,
    );

    var launched = false;
    try {
      launched = await launchUrl(google, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }

    if (!launched && Platform.isIOS) {
      final apple = appleMapsDirectionsUri(
        latitude: place.latitude,
        longitude: place.longitude,
        label: place.name,
      );
      try {
        launched =
            await launchUrl(apple, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open a maps app for directions")),
      );
    }
  }

  Future<void> _call(BuildContext context, Uri uri) async {
    var launched = false;
    try {
      launched = await launchUrl(uri);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the dialler")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Null when the place has no number, or one with no digits in it at all —
    // hide the button rather than opening an empty dialler.
    final tel = telUri(place.phone);

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _openDirections(context, ref),
            icon: const Icon(Icons.directions, size: 18),
            label: const Text('Directions'),
          ),
        ),
        if (tel != null) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _call(context, tel),
            icon: const Icon(Icons.phone, size: 18),
            label: const Text('Call'),
          ),
        ],
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ReviewEntity review;
  final bool isOwn;
  const _ReviewTile({required this.review, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.stars ? Icons.star : Icons.star_border,
                    size: 14,
                    color: AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isOwn ? 'You' : 'Rider',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
          if (review.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.text, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
