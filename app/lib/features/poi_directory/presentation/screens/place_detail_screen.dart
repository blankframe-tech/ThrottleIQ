import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/review_repository.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/place_directions.dart';
import '../providers/places_provider.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../domain/place_tags.dart';
import '../place_category_l10n.dart';
import '../place_tag_l10n.dart';
import '../widgets/place_card.dart';
import '../widgets/place_launch_actions.dart';
import '../widgets/place_rating_badges.dart';

/// Place info header + reviews list + "Add your review" (star picker + text).
///
/// Submitting a review writes the new review doc and recomputes the
/// place's ratingSum/ratingCount in one transaction
/// (`ReviewRepository.addReviewAndUpdatePlaceRating`) — the places/{placeId}
/// security rule only allows the bump in the same commit that creates the
/// rider's review (issues §101.S1).
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
            SnackBar(content: Text(context.l10n.youveAlreadyReviewedThis)),
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
        SnackBar(content: Text(context.l10n.couldNotSubmitReview(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeAsync = ref.watch(placeDetailProvider(widget.placeId));

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(placeAsync.valueOrNull?.name ?? context.l10n.place),
        actions: [
          if (placeAsync.valueOrNull != null)
            PlaceSaveButton(place: placeAsync.valueOrNull!, iconOnly: true),
        ],
      ),
      body: placeAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: context.palette.primary)),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(placeDetailProvider(widget.placeId)),
        ),
        data: (place) {
          if (place == null) {
            return Center(
              child: Text(context.l10n.placeNotFound, style: TextStyle(color: context.palette.textSecondary)),
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
        // §97.4: Added a photo banner to PlaceDetailScreen. We display the first photo in the
        // place.photoUrls array if available, clipped with a border radius for aesthetic appeal.
        if (place.photoUrls.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              place.photoUrls.first,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _PlaceHeader(place: place),
        const SizedBox(height: 24),
        Text(
          context.l10n.addReview,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.palette.textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 1; i <= 5; i++)
              IconButton(
                tooltip: context.l10n.rateThisPlace,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => onStarsChanged(i),
                icon: Icon(
                  i <= selectedStars ? Icons.star : Icons.star_border,
                  color: context.palette.warning,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: reviewController,
          maxLines: 3,
          style: TextStyle(color: context.palette.textPrimary),
          decoration: InputDecoration(hintText: context.l10n.shareExperience),
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
                  : Text(context.l10n.submitReview),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          context.l10n.reviews,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.palette.textPrimary),
        ),
        const SizedBox(height: 12),
        reviewsAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: context.palette.primary)),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(reviewsForPlaceProvider(place.id)),
          ),
          data: (reviews) {
            if (reviews.isEmpty) {
              return Text(
                context.l10n.noReviewsYetBe,
                style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
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
                  color: context.palette.primary.withValues(alpha: 0.1),
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
                          fontSize: 17, fontWeight: FontWeight.w700, color: context.palette.textPrimary),
                    ),
                    Text(place.category.localizedName(context.l10n),
                        style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
                  ],
                ),
              ),
              if (place.verified)
                Tooltip(
                  message: context.l10n.placesVerifiedOnlyHint,
                  child: Icon(Icons.verified, size: 20, color: context.palette.success),
                ),
            ],
          ),
          const SizedBox(height: 10),
          PlaceRatingBadges(place: place),
          if (place.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in PlaceTag.values)
                  if (place.tags.contains(tag))
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${tag.icon} ${tag.localizedName(context.l10n)}',
                          style: const TextStyle(fontSize: 12)),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(height: 1, color: context.palette.border),
          const SizedBox(height: 12),
          // Address is optional on submission (and absent on Overpass imports
          // with no addr:* tags), so an empty one is normal — skip the row
          // entirely rather than rendering a lone pin icon beside blank text.
          if (place.address.trim().isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: context.palette.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(place.address,
                      style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
                ),
              ],
            ),
          if (place.phone != null && place.phone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 16, color: context.palette.textSecondary),
                const SizedBox(width: 8),
                Text(place.phone!, style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
              ],
            ),
          ],
          if (place.hours != null && place.hours!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: context.palette.textSecondary),
                const SizedBox(width: 8),
                Text(place.hours!, style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
              ],
            ),
          ],
          if (!place.category.isSafetyPoint) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.palette.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.map_outlined, size: 13, color: context.palette.textSecondary),
                            const SizedBox(width: 4),
                            Text('Google Maps',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.palette.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          place.hasGoogleRating
                              ? '★ ${place.googleRating.toStringAsFixed(1)} (${place.googleRatingCount})'
                              : context.l10n.n0NotGoogle,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.palette.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: context.palette.border,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.two_wheeler, size: 13, color: context.palette.primary),
                            const SizedBox(width: 4),
                            Text('ThrottleIQ',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.palette.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          place.hasThrottleIqRating
                              ? '★ ${place.averageRating.toStringAsFixed(1)} (${place.ratingCount})'
                              : context.l10n.n00Reviews,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.palette.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
/// button at full width rather than an icon in the app bar. The launch logic
/// is shared with the hub's cards (see [PlaceLaunchActions]).
class _PlaceActions extends ConsumerWidget {
  final PlaceEntity place;
  const _PlaceActions({required this.place});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Null when the place has no number, or one with no digits in it at all —
    // hide the button rather than opening an empty dialler.
    final tel = telUri(place.phone);

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => PlaceLaunchActions.openDirections(context, ref, place),
            icon: const Icon(Icons.directions, size: 18),
            label: Text(context.l10n.directions),
          ),
        ),
        if (tel != null) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => PlaceLaunchActions.call(context, tel),
            // The theme's minimumSize is Size.fromHeight (infinite width),
            // which inside a Row with no Expanded fails layout and blanks
            // the whole screen for any place that has a phone number.
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, context.shape.controlHeight),
            ),
            icon: const Icon(Icons.phone, size: 18),
            label: Text(context.l10n.call),
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
                    color: context.palette.warning,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isOwn ? context.l10n.youLabel : context.l10n.riderFallbackName,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.palette.textPrimary),
              ),
              const Spacer(),
              Text(
                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                style: TextStyle(fontSize: 11, color: context.palette.textTertiary),
              ),
            ],
          ),
          if (review.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.text, style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
          ],
        ],
      ),
    );
  }
}
