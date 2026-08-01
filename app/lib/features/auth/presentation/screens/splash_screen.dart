import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (_, next) {
      next.whenData((user) {
        if (user != null) {
          context.go('/home/record');
        } else {
          context.go('/auth/login');
        }
      });
    });

    // ref.listen misses the initial value if auth resolves before first build.
    // addPostFrameCallback navigates after the frame completes to handle that case.
    ref.watch(authStateProvider).whenData((user) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (user != null) {
          context.go('/home/record');
        } else {
          context.go('/auth/login');
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThrottleIQLogo(),
            SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThrottleIQLogo extends StatelessWidget {
  const _ThrottleIQLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppLogo(size: 80),
        const SizedBox(height: 16),
        Text(
          'ThrottleIQ',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ride smarter. Track deeper.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
