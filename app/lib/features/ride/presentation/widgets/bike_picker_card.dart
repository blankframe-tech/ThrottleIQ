import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../../garage/presentation/widgets/bike_photo.dart';

/// The Record screen's hero: the bike you're about to ride, at full width,
/// with the greeting sitting on top of it — and, when the rider has more than
/// one bike, the control that switches between them **in place**.
///
/// This started life as a small photo-and-name card that navigated to
/// `/home/profile` to change bikes, which cost a trip off the screen and back
/// and promised something it didn't do. Switching now happens here: the
/// Profile tab's garage section is where you *manage* bikes, but choosing
/// which one you're about to ride is a Record-screen decision and shouldn't
/// move you off the screen you're about
/// to start the ride from. That contract is what
/// `test/features/ride/bike_picker_card_test.dart` guards.
///
/// With exactly one bike there is nothing to pick, so no switch affordance is
/// drawn rather than a control that can't do anything. With several, tapping
/// the hero opens a picker sheet — a sheet rather than a dropdown because the
/// hero is a photo, and a dropdown menu anchored to a 200px image either
/// covers the thing you're choosing or floats off it.
class BikePickerCard extends ConsumerWidget {
  const BikePickerCard({
    super.key,
    required this.activeBike,
    this.overlineText,
    this.titleText,
  });

  final BikeEntity activeBike;

  /// Small line above the title — the casual half of the greeting, when the
  /// picked variant didn't weave the rider's name into the title itself.
  final String? overlineText;

  /// The large line across the hero, normally the greeting.
  final String? titleText;

  static const double _height = 210;

  Future<void> _pickBike(
      BuildContext context, WidgetRef ref, List<BikeEntity> bikes) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingMd, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                      child: Text(l10n.bikePickerSheetTitle,
                          style: display(16, letterSpacing: 0))),
                ],
              ),
            ),
            for (final bike in bikes)
              ListTile(
                onTap: () => Navigator.pop(sheetContext, bike.id),
                // Ride count rather than "Ready to ride": every row would say
                // the same thing, which distinguishes nothing. How much
                // you've ridden each bike is what tells them apart when the
                // names are similar.
                title: BikeRow(
                  bike: bike,
                  subtitle: l10n.rideCountLabel(bike.rideCount),
                  trailing: bike.id == activeBike.id
                      ? Icon(Icons.check, size: 18, color: AppColors.primary)
                      : null,
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null || picked == activeBike.id) return;
    ref.read(garageProvider.notifier).setActiveBike(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bikes = ref.watch(garageProvider).valueOrNull ?? const <BikeEntity>[];
    final canSwitch = bikes.length >= 2;
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: canSwitch ? () => _pickBike(context, ref, bikes) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Container(
          height: _height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              BikePhoto(
                imagePath: activeBike.imagePath,
                borderRadius: BorderRadius.zero,
                iconSize: 64,
                iconColor: AppColors.textTertiary,
              ),
              // Scrim. The photo is the rider's own, so it can be anything
              // from a bright daylight shot to a night one — text laid
              // straight onto it is legible on neither. The gradient is
              // opaque enough at the bottom to guarantee contrast for the
              // copy and thin enough at the top to leave the bike visible.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.ink.withValues(alpha: 0.15),
                      AppColors.ink.withValues(alpha: 0.55),
                      AppColors.ink.withValues(alpha: 0.88),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (overlineText != null) ...[
                      Text(
                        overlineText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.onInk.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: 2),
                    ],
                    if (titleText != null)
                      Text(
                        titleText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: display(24, color: AppColors.onInk, height: 1.15),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            activeBike.displayName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppColors.onInk,
                            ),
                          ),
                        ),
                        if (canSwitch) ...[
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.changeAction.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: AppColors.onInk.withValues(alpha: 0.85),
                                ),
                              ),
                              Icon(Icons.expand_more,
                                  size: 18,
                                  color: AppColors.onInk.withValues(alpha: 0.85)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One bike as photo + name + a caption. Used by the picker sheet, and kept
/// separate so anything else listing bikes reads the same.
class BikeRow extends StatelessWidget {
  const BikeRow({
    super.key,
    required this.bike,
    required this.subtitle,
    this.trailing,
  });

  final BikeEntity bike;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // The rider's own photo of this bike when there is one, otherwise the
        // generic icon tile (see [BikePhoto]).
        BikePhoto(
          imagePath: bike.imagePath,
          width: 44,
          height: 44,
          iconSize: 24,
          iconColor: AppColors.textPrimary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bike.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: display(16, letterSpacing: 0)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}
