import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much of the community side of the app a rider wants.
enum CommunityMode {
  /// Ride feed, people, chat, group rides and forums.
  full,

  /// Forums only: no ride feed, people, chat, follows or group rides.
  forumsOnly,

  /// No community features at all.
  off,
}

/// Settings → "Your ThrottleIQ": which parts of the app a rider uses.
///
/// For riders who want a smaller, more private app. Turning a module off hides
/// its tab, its entry points and its routes; it deletes nothing, so turning it
/// back on restores everything. Stored on this device only.
class AppModules {
  const AppModules({
    this.community = CommunityMode.full,
    this.places = true,
    this.rideTracking = true,
    this.simple = false,
  });

  final CommunityMode community;

  /// Places, saved places and routes.
  final bool places;

  /// Recording, auto-detection, ride analytics and anything else that reads
  /// the rider's location. Off leaves a maintenance-only app.
  final bool rideTracking;

  /// Simple mode (ThrottleEZ): a small app (People, Home, Rides, Bike) for
  /// riders who want the basics. Hides forums, chat, the ride feed, places,
  /// routes and analytics on top of whatever the other modules hide; changes
  /// no data.
  final bool simple;

  /// The ride feed, chat, group rides, ride sharing and notifications.
  bool get social => !simple && community == CommunityMode.full;
  bool get forums => !simple && community != CommunityMode.off;

  /// Finding riders, following them and their profiles. Part of [social] in
  /// the full app; Simple mode keeps just this, as its People tab.
  bool get people => community == CommunityMode.full;

  AppModules copyWith({
    CommunityMode? community,
    bool? places,
    bool? rideTracking,
    bool? simple,
  }) =>
      AppModules(
        community: community ?? this.community,
        places: places ?? this.places,
        rideTracking: rideTracking ?? this.rideTracking,
        simple: simple ?? this.simple,
      );

  /// The bottom-nav tabs, in display order. Never fewer than two: Garage is
  /// always there, and Maintenance takes Record's place when tracking is off.
  List<String> get tabs => simple
      // Same order as the full bar (Social first, Record, Rides, Garage), so
      // switching modes doesn't move the tabs under the rider's thumb.
      ? [
          if (people) '/home/simple-people',
          '/home/simple',
          if (rideTracking) '/home/simple-rides',
          '/home/simple-bike',
        ]
      : [
          if (forums) '/home/social',
          if (places) '/home/places',
          if (rideTracking) ...['/home/record', '/home/stats'],
          if (!rideTracking) '/home/maintenance',
          '/home/profile',
        ];

  /// Where the app opens, and where a turned-off route lands.
  String get home => simple
      ? '/home/simple'
      : rideTracking
          ? '/home/record'
          : '/home/maintenance';

  /// [home] when [location] belongs to a module that is off, else null.
  ///
  /// [simpleBikeId] is the bike Simple mode's Bike tab shows. A maintenance
  /// link for any other bike (a two-bike rider's alert) keeps its own page
  /// rather than landing on the wrong bike's checklist.
  String? redirectFor(String location, {String? simpleBikeId}) {
    final path = location.split('?').first;
    bool under(String base) => path == base || path.startsWith('$base/');

    if (simple && path == '/home/maintenance') {
      final bikeId = Uri.parse(location).queryParameters['bikeId'];
      if (bikeId == null || bikeId == simpleBikeId) return '/home/simple-bike';
    }
    final simpleOnly = under('/home/simple') ||
        under('/home/simple-rides') ||
        under('/home/simple-bike') ||
        under('/home/simple-people');
    if (!simple && simpleOnly) return home;
    // A follow link lands on Social's People tab; Simple has its own.
    if (simple && people && under('/home/social')) return '/home/simple-people';

    final blocked = (!forums && (under('/home/social') || under('/forums'))) ||
        (!people &&
            (under('/people') ||
                // Other riders' profiles and the follow QR; '/profile' (own)
                // and '/profile/edit' stay.
                (under('/profile') &&
                    path != '/profile' &&
                    path != '/profile/edit'))) ||
        (!social &&
            (under('/chats') ||
                under('/notifications') ||
                under('/group-ride') ||
                under('/rides/shared') ||
                under('/rides/mine') ||
                under('/ride/share'))) ||
        (!places &&
            (under('/home/places') || under('/places') || under('/routes'))) ||
        (!rideTracking &&
            (under('/home/record') ||
                under('/home/stats') ||
                under('/ride') ||
                under('/rides/all') ||
                under('/group-ride') ||
                under('/routes/save') ||
                (under('/routes') && path.endsWith('/navigate')))) ||
        (simple &&
            (under('/home/record') ||
                under('/home/stats') ||
                under('/home/social') ||
                under('/home/places') ||
                under('/places') ||
                under('/routes') ||
                under('/rides/all') ||
                path == '/home/profile' ||
                (!rideTracking && under('/home/simple-rides')) ||
                (!people && under('/home/simple-people'))));
    return blocked ? home : null;
  }
}

final appModulesProvider =
    StateNotifierProvider<AppModulesNotifier, AppModules>(
        (ref) => AppModulesNotifier());

class AppModulesNotifier extends StateNotifier<AppModules> {
  AppModulesNotifier() : super(const AppModules()) {
    _load();
  }

  static const _communityKey = 'module_community';
  static const _placesKey = 'module_places';
  static const _rideTrackingKey = 'module_ride_tracking';
  static const _simpleKey = 'module_simple';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final community = prefs.getString(_communityKey);
    if (!mounted) return;
    state = AppModules(
      community:
          CommunityMode.values.where((m) => m.name == community).firstOrNull ??
              CommunityMode.full,
      places: prefs.getBool(_placesKey) ?? true,
      rideTracking: prefs.getBool(_rideTrackingKey) ?? true,
      simple: prefs.getBool(_simpleKey) ?? false,
    );
  }

  Future<void> set(AppModules modules) async {
    state = modules;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_communityKey, modules.community.name);
    await prefs.setBool(_placesKey, modules.places);
    await prefs.setBool(_rideTrackingKey, modules.rideTracking);
    await prefs.setBool(_simpleKey, modules.simple);
  }
}
