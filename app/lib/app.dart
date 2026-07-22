import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/cloud/sync_manager.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

class ThrottleIQApp extends ConsumerWidget {
  const ThrottleIQApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      // Cloud sync lifecycle: start on login, stop on logout. SyncManager itself
      // no-ops when signed out, so starting is safe; stopping avoids idle timers.
      ref.listen(authStateProvider, (prev, next) {
        final sync = ref.read(syncManagerProvider);
        if (next.valueOrNull != null) {
          sync.startAutoSync();
        } else {
          sync.stopAutoSync();
        }
      });

      final router = ref.watch(routerProvider);
      return MaterialApp.router(
        title: 'ThrottleIQ',
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      );
    } catch (e) {
      print('App initialization error: $e');
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error: $e'),
          ),
        ),
      );
    }
  }
}
