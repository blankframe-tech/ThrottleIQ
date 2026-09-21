import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/formatters/speed_formatter.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../providers/garage_provider.dart';
import '../widgets/bike_photo.dart';
import '../../domain/entities/bike_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../social/presentation/providers/notification_providers.dart';
import '../../../../shared/widgets/notification_bell_button.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../core/i18n/l10n_context.dart';

/// The Profile tab's root screen (route `/home/profile`).
///
/// Leads with the rider's own profile, plus the Settings and Notifications
/// entry points that used to sit in RecordScreen's header — moved here so
/// account-level chrome lives on the tab actually named "Profile" rather than
/// floating over the ride-recording screen. The bike garage stays underneath:
/// it's still the tab's main content, just no longer the *only* thing on it.
class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bikesAsync = ref.watch(garageProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: profile summary (tap for Profile / My Places / My
            // Shared Rides), then Notifications and Settings — the two
            // account-level actions RecordScreen used to carry.
            Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 12,
                  AppDimensions.paddingMd, 4),
              child: Row(
                children: [
                  const Expanded(child: _ProfileSummary()),
                  NotificationBellButton(
                      unreadCount: ref.watch(unreadNotificationCountProvider)),
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: context.l10n.settingsTitle,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingMd, 12, AppDimensions.paddingMd, 8),
              child: Text(context.l10n.yourBikesTitle, style: display(context, 22)),
            ),
            Expanded(
              child: bikesAsync.when(
                loading: () => Center(
                    child: CircularProgressIndicator(color: context.palette.primary)),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(garageProvider),
                ),
                data: (bikes) {
                  final archived = ref.watch(archivedBikesProvider);
                  if (bikes.isEmpty && archived.isEmpty) {
                    return const _EmptyGarage();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd, 4,
                        AppDimensions.paddingMd, AppDimensions.paddingLg),
                    itemCount: bikes.length + 1 + (archived.isEmpty ? 0 : 1),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => i < bikes.length
                        ? _BikeCard(bike: bikes[i])
                        : i == bikes.length
                            ? DashedAddButton(
                                label: context.l10n.addABike,
                                onTap: () => context.go('/home/profile/add'),
                              )
                            : _ArchivedBikesSection(bikes: archived),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile summary at the top of the Profile tab: avatar, name, and a "View
/// profile" hint, tappable for the same menu the old avatar-only button
/// opened (profile / my places / my shared rides).
class _ProfileSummary extends ConsumerWidget {
  const _ProfileSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final name = profile?.bestName ?? user?.displayName ?? 'Rider';

    return GestureDetector(
      onTap: () => _showMenu(context),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          UserAvatar(
            photoUrl: profile?.photoUrl ?? user?.photoURL,
            name: name,
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: display(context, 18, letterSpacing: 0),
                    overflow: TextOverflow.ellipsis),
                Text(context.l10n.viewProfile,
                    style:
                        TextStyle(fontSize: 12, color: context.palette.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Pops with the destination path as the sheet's result rather than
  // popping-then-pushing inline: a Navigator.pop immediately followed by a
  // context.push in the same synchronous callback races the sheet's
  // imperative route removal against go_router's declarative page-list
  // update on the same Navigator, which can produce two pages computing
  // the same key -- Flutter's Navigator._updatePages assertion
  // "'!keyReservation.contains(key)': is not true." (confirmed crash site:
  // this exact menu, tapping "My Places"). Awaiting the sheet's own Future
  // and pushing only after it fully resolves guarantees the sheet's route
  // is completely gone before anything else touches the Navigator.
  Future<void> _showMenu(BuildContext context) async {
    final destination = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.palette.background,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person_outline, color: sheetContext.palette.primary),
              title: Text(sheetContext.l10n.navProfileLabel),
              // The read-only profile view, not the edit form — editing is an
              // action inside it now.
              onTap: () => Navigator.pop(sheetContext, '/profile'),
            ),
            ListTile(
              leading: Icon(Icons.place_outlined, color: sheetContext.palette.primary),
              title: Text(sheetContext.l10n.myPlaces),
              onTap: () => Navigator.pop(sheetContext, '/places/mine'),
            ),
            ListTile(
              leading: Icon(Icons.ios_share, color: sheetContext.palette.primary),
              title: Text(sheetContext.l10n.mySharedRides),
              onTap: () => Navigator.pop(sheetContext, '/rides/mine'),
            ),
          ],
        ),
      ),
    );
    if (destination != null && context.mounted) context.push(destination);
  }
}

class _EmptyGarage extends StatelessWidget {
  const _EmptyGarage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.garage_outlined, size: 56, color: context.palette.textTertiary),
            const SizedBox(height: 16),
            Text(context.l10n.noBikesYet, style: display(context, 20)),
            const SizedBox(height: 6),
            Text(context.l10n.addFirstBikeGet,
                style: TextStyle(color: context.palette.textTertiary, fontSize: 14)),
            const SizedBox(height: 20),
            DashedAddButton(
              label: context.l10n.addABike,
              onTap: () => context.go('/home/profile/add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BikeCard extends ConsumerWidget {
  final BikeEntity bike;
  const _BikeCard({required this.bike});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EditorialCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go('/home/profile/${bike.id}'),
      borderColor: bike.isActive ? context.palette.primary : context.palette.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo strip — the rider's own photo of the bike if they attached
          // one and the file is still there, otherwise the generic icon.
          Stack(
            children: [
              BikePhoto(
                imagePath: bike.imagePath,
                width: double.infinity,
                height: 116,
                iconSize: 44,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(context.shape.radiusXl)),
              ),
              if (bike.isActive)
                const Positioned(
                  top: 12,
                  right: 12,
                  child: EditorialPill('Active', tone: PillTone.accent),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(bike.displayName, style: display(context, 18, letterSpacing: 0)),
                    ),
                    if (!bike.isActive)
                      TextButton(
                        onPressed: () =>
                            ref.read(garageProvider.notifier).setActiveBike(bike.id),
                        style: TextButton.styleFrom(
                            foregroundColor: context.palette.textSecondary,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(60, 32)),
                        child: Text(context.l10n.setActive, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                if (bike.cc != null)
                  Text('${bike.cc}cc',
                      style: TextStyle(fontSize: 13, color: context.palette.textSecondary)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: StatCell(
                        value: SpeedFormatter.distanceKm(bike.totalDistanceM),
                        label: context.l10n.totalLower,
                        valueSize: 18,
                      ),
                    ),
                    Expanded(
                      child: StatCell(value: '${bike.rideCount}', label: context.l10n.ridesLower, valueSize: 18),
                    ),
                    Expanded(
                      child: StatCell(
                        value: bike.lastRideAt != null
                            ? '${DateTime.now().difference(bike.lastRideAt!).inDays}d'
                            : '—',
                        label: context.l10n.lastRide,
                        valueSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // A real button with a full-width, 48 dp target rather than a
                // ~28 dp text row nested in the card's own onTap: a tap
                // anywhere on it goes to maintenance, never falls through to
                // bike detail (grill §3.2.2). Pushed rather than
                // go()-ed so the Maintenance screen's back bar returns here.
                TextButton.icon(
                  onPressed: () =>
                      context.push('/home/maintenance?bikeId=${bike.id}'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                    foregroundColor: context.palette.primary,
                  ),
                  icon: const Icon(Icons.build_outlined, size: 18),
                  label: Text(context.l10n.maintenance,
                      style: display(context, 14,
                          letterSpacing: 0, color: context.palette.primary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bikes the rider archived: out of the garage and every picker, but with
/// their rides still in history and stats. Collapsed by default — these are
/// bikes the rider chose to put away.
class _ArchivedBikesSection extends ConsumerWidget {
  final List<BikeEntity> bikes;
  const _ArchivedBikesSection({required this.bikes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EditorialCard(
      padding: EdgeInsets.zero,
      child: Theme(
        // ExpansionTile draws its own dividers when expanded; inside a card
        // with its own border they read as stray lines.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('archived-bikes-section'),
          leading: Icon(Icons.inventory_2_outlined, color: context.palette.textSecondary),
          title: Text(context.l10n.archivedBikes(bikes.length),
              style: display(context, 16, letterSpacing: 0)),
          children: [
            for (final bike in bikes)
              ListTile(
                title: Text(bike.displayName),
                subtitle: Text(
                    context.l10n.ridesAndDistance(bike.rideCount, SpeedFormatter.distanceKm(bike.totalDistanceM)),
                    style: TextStyle(color: context.palette.textSecondary)),
                onTap: () => context.go('/home/profile/${bike.id}'),
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(garageProvider.notifier).unarchiveBike(bike.id),
                  child: Text(context.l10n.unarchive),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
