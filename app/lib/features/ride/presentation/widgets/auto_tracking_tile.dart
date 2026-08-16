import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/auto_tracking_provider.dart';

/// Settings control for automatic ride detection.
///
/// The battery figure in the subtitle is deliberate and specific. Riders are a
/// technical, sceptical audience and "uses some battery" reads as evasion;
/// naming the number is what makes the ask credible. It is also honest — the
/// idle cost really is a few percent a day, because detection runs on platform
/// activity recognition and never polls GPS. See docs/AUTO_TRACKING_PLAN.md.
///
/// NOTE: copy here is in English literals, unlike the rest of
/// `settings_screen.dart`, which reads from [AppLocalizations]. Bangla parity
/// needs matching keys in `lib/l10n/app_en.arb` and `app_bn.arb` before this
/// ships — `test/core/i18n/arb_parity_test.dart` guards the two ARB files
/// against each other but cannot see a hardcoded string.
class AutoTrackingTile extends ConsumerWidget {
  const AutoTrackingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(autoTrackingEnabledProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        value: enabled.valueOrNull ?? false,
        onChanged: enabled.isLoading
            ? null
            : (value) => _toggle(context, ref, value),
        title: const Text(
          'Detect rides automatically',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Logs a ride without you tapping start. Uses about 3–5% battery a '
          'day when you are not riding.',
        ),
        secondary: Icon(Icons.motorcycle, color: AppColors.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    final notifier = ref.read(autoTrackingEnabledProvider.notifier);

    if (!value) {
      await notifier.disable();
      return;
    }

    final error = await notifier.enable();
    if (error == null || !context.mounted) return;

    // Enabling can fail for reasons the rider can act on (services off,
    // permission refused), so the failure is surfaced rather than the switch
    // silently springing back with no explanation.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), duration: const Duration(seconds: 5)),
    );
  }
}
