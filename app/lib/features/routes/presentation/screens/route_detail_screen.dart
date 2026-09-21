import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/ride_route_map.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../social/data/repositories/route_repository.dart';
import '../../domain/route_permissions.dart';
import '../../domain/turn_instruction.dart';
import '../providers/route_providers.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../core/i18n/l10n_context.dart';

/// One saved route: the line on a map, its stats, its turn list, and the
/// entry point into navigation.
///
/// Opens in two modes. Owned: everything, including the public/private toggle
/// and Delete. Discovered ([ownerUid] naming another rider): read-only —
/// firestore.rules refuse a non-owner's writes, so the controls that would be
/// refused aren't shown at all, and a line says whose route it is. Navigation
/// works either way; following a track reads nothing but the route itself.
class RouteDetailScreen extends ConsumerWidget {
  final String routeId;

  /// The rider the route belongs to. Null means "the signed-in rider" — every
  /// link from "My routes" omits it.
  final String? ownerUid;

  const RouteDetailScreen({
    super.key,
    required this.routeId,
    this.ownerUid,
  });

  RouteLookup get _lookup => (routeId: routeId, ownerUid: ownerUid);

  Future<void> _setPublic(
      BuildContext context, WidgetRef ref, bool isPublic) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    try {
      await RouteRepository().setPublic(uid, routeId, isPublic);
      if (!context.mounted) return;
      ref.invalidate(routeByIdProvider(_lookup));
      ref.invalidate(myRoutesProvider);
      ref.invalidate(publicRoutesProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotUpdateVisibility(e))),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.palette.surface,
        title: Text(ctx.l10n.deleteRouteQuestion, style: TextStyle(color: ctx.palette.textPrimary)),
        content: Text(
          ctx.l10n.thisRemovesSavedRoute,
          style: TextStyle(color: ctx.palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancelAction, style: TextStyle(color: ctx.palette.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.delete, style: TextStyle(color: ctx.palette.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    try {
      await RouteRepository().deleteRoute(uid, routeId);
      if (!context.mounted) return;
      ref.invalidate(myRoutesProvider);
      ref.invalidate(publicRoutesProvider);
      context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotDelete(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeAsync = ref.watch(routeByIdProvider(_lookup));
    final viewerUid = ref.watch(currentUserProvider)?.uid;

    // The route's own userId is authoritative once it has loaded; the query
    // parameter is only how we found it.
    final owner = routeAsync.valueOrNull?.userId ?? ownerUid;
    final canEdit = canEditRoute(viewerUid: viewerUid, ownerUid: owner);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text(routeAsync.valueOrNull?.name ?? context.l10n.routeSectionLabel),
        // Same no-back-stack guard as RoutesListScreen — a deep link straight
        // to a route would otherwise render no back button at all.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.l10n.back,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/routes'),
        ),
        actions: [
          // Delete is owner-only — the rules refuse anyone else, so a
          // discovered route doesn't get a button that can only fail.
          if (routeAsync.valueOrNull != null && canEdit)
            IconButton(
              icon: Icon(Icons.delete_outline, color: context.palette.textSecondary),
              tooltip: context.l10n.deleteRouteTitle,
              onPressed: () => _delete(context, ref),
            ),
        ],
      ),
      body: routeAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: context.palette.primary)),
        error: (e, _) =>
            ErrorView(
          error: e,
          onRetry: () => ref.invalidate(routeByIdProvider(_lookup)),
        ),
        data: (route) {
          if (route == null) {
            return Center(
              child: Text(context.l10n.routeNotFound,
                  style: TextStyle(color: context.palette.textSecondary)),
            );
          }

          final turns = buildTurnInstructions(route.polyline);
          final manoeuvres = turns
              .where((t) =>
                  t.kind != TurnKind.start && t.kind != TurnKind.arrive)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            children: [
              RideRouteMap(polyline: route.polyline, height: 220),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Stat(
                    label: context.l10n.distanceLabel,
                    value: '${route.distanceKm.toStringAsFixed(1)} km',
                  ),
                  _Stat(label: context.l10n.turns, value: '${manoeuvres.length}'),
                  _Stat(label: context.l10n.ridden, value: '${route.timesRidden}×'),
                ],
              ),
              if (route.description != null && route.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  route.description!,
                  style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
                ),
              ],
              const SizedBox(height: 20),
              // Visibility is the owner's to change. A non-owner gets the
              // attribution line instead — the toggle would be refused by
              // firestore.rules, and "Only you can see this route" would be a
              // lie on somebody else's route besides.
              if (canEdit)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(context.shape.radiusMd),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: route.isPublic,
                    activeThumbColor: context.palette.primary,
                    onChanged: (v) => _setPublic(context, ref, v),
                    title: Text(
                      route.isPublic ? context.l10n.audiencePublic : context.l10n.privateLabel,
                      style:
                          TextStyle(fontSize: 14, color: context.palette.textPrimary),
                    ),
                    subtitle: Text(
                      route.isPublic
                          ? context.l10n.anyRiderCanFind
                          : context.l10n.onlyCanSeeThis,
                      style: TextStyle(
                          fontSize: 12, color: context.palette.textSecondary),
                    ),
                  ),
                )
              else
                _SharedByBanner(ownerUid: route.userId),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: route.polyline.length < 2
                    ? null
                    // Navigation is read-only, so it works on a discovered
                    // route too — it just has to be told whose it is.
                    : () => context.push(canEdit
                        ? '/routes/$routeId/navigate'
                        : '/routes/$routeId/navigate'
                            '?owner=${Uri.encodeComponent(route.userId)}'),
                icon: const Icon(Icons.navigation_outlined, size: 18),
                label: Text(context.l10n.startNavigation),
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.turnByTurn,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.derivedFromRecordedTrack,
                style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
              ),
              const SizedBox(height: 12),
              for (final turn in turns)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(turnIcon(turn.kind), size: 20, color: context.palette.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          turn.text,
                          style: TextStyle(
                              fontSize: 14, color: context.palette.textPrimary),
                        ),
                      ),
                      Text(
                        _distanceLabel(turn.distanceFromStartM),
                        style: TextStyle(
                            fontSize: 12, color: context.palette.textTertiary),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _distanceLabel(double metres) {
  if (metres < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}

/// Maps a manoeuvre to the arrow shown beside it. Kept here (presentation)
/// rather than on [TurnKind] so the domain module stays Flutter-free.
IconData turnIcon(TurnKind kind) {
  switch (kind) {
    case TurnKind.start:
      return Icons.trip_origin;
    case TurnKind.slightLeft:
      return Icons.turn_slight_left;
    case TurnKind.left:
      return Icons.turn_left;
    case TurnKind.sharpLeft:
      return Icons.turn_sharp_left;
    case TurnKind.slightRight:
      return Icons.turn_slight_right;
    case TurnKind.right:
      return Icons.turn_right;
    case TurnKind.sharpRight:
      return Icons.turn_sharp_right;
    case TurnKind.uTurn:
      return Icons.u_turn_left;
    case TurnKind.straight:
      return Icons.straight;
    case TurnKind.arrive:
      return Icons.flag_outlined;
  }
}

/// Attribution shown in place of the visibility toggle on somebody else's
/// route. Names the owner when their profile is readable; a profile the rules
/// or the network refuse degrades to "another rider" rather than an error —
/// the route itself is public and perfectly viewable without a name.
class _SharedByBanner extends ConsumerWidget {
  final String ownerUid;
  const _SharedByBanner({required this.ownerUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ownerUid.isEmpty
        ? null
        : ref.watch(profileProvider(ownerUid)).valueOrNull?.bestName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.public, size: 18, color: context.palette.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null || name.trim().isEmpty
                      ? context.l10n.sharedByAnotherRider
                      : context.l10n.sharedBy(name),
                  style:
                      TextStyle(fontSize: 14, color: context.palette.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.canRideItBut,
                  style:
                      TextStyle(fontSize: 12, color: context.palette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
        ],
      ),
    );
  }
}
