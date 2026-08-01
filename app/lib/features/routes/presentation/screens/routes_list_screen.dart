import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/ride_route_map.dart';
import '../../../social/domain/entities/route_entity.dart';
import '../providers/route_providers.dart';

/// Saved routes: the rider's own, plus public ones from everyone else.
///
/// "Places to ride" in the sense the backlog asks for — a route here is a road
/// someone has actually ridden, saved off the end of a ride.
class RoutesListScreen extends StatelessWidget {
  const RoutesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Routes'),
          // Explicit, rather than relying on AppBar's automatic back button.
          // This screen is also reachable without a back stack (a deep link,
          // or a cold launch straight to /routes), and in that case the
          // automatic leading isn't rendered at all — leaving the rider
          // stranded on a full-screen page with no way out. Pop when there's
          // something to pop, otherwise fall back to the tab it belongs to.
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home/places');
              }
            },
          ),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'My routes'),
              Tab(text: 'Discover'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RoutesTab(mine: true),
            _RoutesTab(mine: false),
          ],
        ),
      ),
    );
  }
}

class _RoutesTab extends ConsumerWidget {
  final bool mine;
  const _RoutesTab({required this.mine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mine ? myRoutesProvider : publicRoutesProvider;
    final routesAsync = ref.watch(provider);

    return routesAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) =>
          Center(child: Text('$e', style: TextStyle(color: AppColors.danger))),
      data: (routes) {
        if (routes.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_outlined, size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    mine ? 'No saved routes yet' : 'No public routes yet',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mine
                        ? 'Finish a ride, then tap "Save as route" on the share screen.'
                        : 'Public routes other riders save will show up here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(provider.future),
          color: AppColors.primary,
          child: ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            itemCount: routes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _RouteCard(route: routes[i], tappable: mine),
          ),
        );
      },
    );
  }
}

class _RouteCard extends StatelessWidget {
  final RouteEntity route;

  /// Discovered routes belong to another rider, so their detail screen (which
  /// looks routes up under the *signed-in* rider's uid) can't open them yet.
  final bool tappable;

  const _RouteCard({required this.route, required this.tappable});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: tappable ? () => context.push('/routes/${route.id}') : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RideRouteMap(polyline: route.polyline, height: 130),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  route.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ),
              Icon(
                route.isPublic ? Icons.public : Icons.lock_outline,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${route.distanceKm.toStringAsFixed(1)} km · ridden ${route.timesRidden}×',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (route.description != null && route.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              route.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
