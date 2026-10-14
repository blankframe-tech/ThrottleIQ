import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/app_modules.dart';
import '../../core/theme/app_theme_context.dart';
import '../../features/auth/presentation/widgets/tour_floating_banner.dart';
import '../../l10n/app_localizations.dart';

/// Every bottom-nav destination with all modules on, in display order. The
/// live list is [AppModules.tabs]; a location's index in that list *is* its
/// `BottomNavigationBar` index.
const List<String> shellTabs = [
  '/home/social',
  '/home/places',
  '/home/record',
  '/home/stats',
  '/home/profile',
];

/// Shell routes that are *not* tabs of their own, mapped to the tab they
/// logically belong under.
///
/// Without this, `/home/maintenance` matched no tab prefix and silently fell
/// through to the Record fallback — the bug reported as "the maintenance page
/// from garage, when selected, shows that I'm on record page in bottom but
/// opens the maintenance page correctly." Maintenance is only ever reached
/// from a bike card on the Profile tab's garage section, so it highlights
/// Profile.
/// Maintenance is its own tab when ride tracking is off, which wins over this.
const Map<String, String> _nonTabShellRoutes = {
  '/home/maintenance': '/home/profile',
};

/// Maps a shell location to the bottom-nav index that should appear selected.
///
/// Pure so it can be unit-tested without a widget tree. Matches a tab when the
/// location *is* the tab path or is nested under it (`/home/profile/abc/edit`
/// → Profile), then falls back to the home tab (Record, or Maintenance with
/// tracking off) for anything unrecognised. The fallback exists only so
/// `BottomNavigationBar` always gets a valid index — a new shell route that
/// should highlight a specific tab belongs in [_nonTabShellRoutes], not in the
/// fallback.
int shellTabIndexForLocation(String location,
    [AppModules modules = const AppModules()]) {
  final tabs = modules.tabs;
  final path = location.split('?').first;

  bool matches(String base) => path == base || path.startsWith('$base/');

  final idx = tabs.indexWhere(matches);
  if (idx >= 0) return idx;

  for (final entry in _nonTabShellRoutes.entries) {
    if (matches(entry.key)) return tabs.indexOf(entry.value);
  }

  return tabs.indexOf(modules.home);
}

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(appModulesProvider);
    final tabs = modules.tabs;
    final idx = shellTabIndexForLocation(
        GoRouterState.of(context).matchedLocation, modules);
    final l10n = AppLocalizations.of(context);
    final items = {
      '/home/social': modules.social
          ? BottomNavigationBarItem(
              icon: const Icon(Icons.people_outline),
              activeIcon: const Icon(Icons.people),
              label: l10n.navSocialLabel)
          : BottomNavigationBarItem(
              icon: const Icon(Icons.forum_outlined),
              activeIcon: const Icon(Icons.forum),
              label: l10n.forums),
      '/home/places': BottomNavigationBarItem(
          icon: const Icon(Icons.place_outlined),
          activeIcon: const Icon(Icons.place),
          label: l10n.navPlacesLabel),
      '/home/record': BottomNavigationBarItem(
          icon: const Icon(Icons.radio_button_checked_outlined),
          activeIcon: const Icon(Icons.radio_button_checked),
          label: l10n.navRecordLabel),
      '/home/stats': BottomNavigationBarItem(
          icon: const Icon(Icons.insights_outlined),
          activeIcon: const Icon(Icons.insights),
          label: l10n.navRidesLabel),
      '/home/maintenance': BottomNavigationBarItem(
          icon: const Icon(Icons.build_outlined),
          activeIcon: const Icon(Icons.build),
          label: l10n.maintenance),
      '/home/profile': BottomNavigationBarItem(
          icon: const Icon(Icons.two_wheeler_outlined),
          activeIcon: const Icon(Icons.two_wheeler),
          label: l10n.navGarageLabel),
    };
    return Scaffold(
      body: Stack(
        children: [
          child,
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TourFloatingBanner(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          border:
              Border(top: BorderSide(color: context.palette.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: idx,
          onTap: (i) => context.go(tabs[i]),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: context.palette.primary,
          unselectedItemColor: context.palette.textTertiary,
          selectedLabelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [for (final t in tabs) items[t]!],
        ),
      ),
    );
  }
}
