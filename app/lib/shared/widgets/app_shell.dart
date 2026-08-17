import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// The bottom-nav destinations, in display order — a location's index in this
/// list *is* its `BottomNavigationBar` index.
const List<String> shellTabs = [
  '/home/social',
  '/home/places',
  '/home/record',
  '/home/stats',
  '/home/profile',
];

const int _recordTabIndex = 2;
const int _profileTabIndex = 4;

/// Shell routes that are *not* tabs of their own, mapped to the tab they
/// logically belong under.
///
/// Without this, `/home/maintenance` matched no tab prefix and silently fell
/// through to the Record fallback — the bug reported as "the maintenance page
/// from garage, when selected, shows that I'm on record page in bottom but
/// opens the maintenance page correctly." Maintenance is only ever reached
/// from a bike card on the Profile tab's garage section, so it highlights
/// Profile.
const Map<String, int> _nonTabShellRoutes = {
  '/home/maintenance': _profileTabIndex,
};

/// Maps a shell location to the bottom-nav index that should appear selected.
///
/// Pure so it can be unit-tested without a widget tree. Matches a tab when the
/// location *is* the tab path or is nested under it (`/home/profile/abc/edit`
/// → Profile), then falls back to Record for anything unrecognised. The
/// fallback exists only so `BottomNavigationBar` always gets a valid index —
/// a new shell route that should highlight a specific tab belongs in
/// [_nonTabShellRoutes], not in the fallback.
int shellTabIndexForLocation(String location) {
  final path = location.split('?').first;

  bool matches(String base) => path == base || path.startsWith('$base/');

  for (final entry in _nonTabShellRoutes.entries) {
    if (matches(entry.key)) return entry.value;
  }

  final idx = shellTabs.indexWhere(matches);
  return idx < 0 ? _recordTabIndex : idx;
}

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _currentIndex(BuildContext context) =>
      shellTabIndexForLocation(GoRouterState.of(context).matchedLocation);

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: idx,
          onTap: (i) => context.go(shellTabs[i]),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiary,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.people_outline), activeIcon: const Icon(Icons.people), label: l10n.navSocialLabel),
            BottomNavigationBarItem(icon: const Icon(Icons.place_outlined), activeIcon: const Icon(Icons.place), label: l10n.navPlacesLabel),
            BottomNavigationBarItem(icon: const Icon(Icons.radio_button_checked_outlined), activeIcon: const Icon(Icons.radio_button_checked), label: l10n.navRecordLabel),
            BottomNavigationBarItem(icon: const Icon(Icons.insights_outlined), activeIcon: const Icon(Icons.insights), label: l10n.navRidesLabel),
            BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: l10n.navProfileLabel),
          ],
        ),
      ),
    );
  }
}
