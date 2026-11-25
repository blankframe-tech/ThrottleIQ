import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_context.dart';

/// The gear on every Simple tab: Settings is the only way back to the Simple
/// mode switch, since Simple hides the Profile tab. IconButton is 48dp.
class SimpleSettingsButton extends StatelessWidget {
  const SimpleSettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        key: const Key('simple_settings_button'),
        icon: const Icon(Icons.settings_outlined),
        tooltip: context.l10n.settingsTitle,
        onPressed: () => context.push('/settings'),
      );
}
