import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../social/presentation/screens/social_screen.dart';
import '../widgets/simple_home_help_sheet.dart';
import '../widgets/simple_section.dart';
import '../widgets/simple_settings_button.dart';
import '../widgets/simple_theme.dart';

/// Simple mode People tab: find riders and follow them. The full app's
/// People tab on its own: no ride feed, forums or chat (the profile it opens
/// hides Message, since Simple keeps AppModules.social off).
class SimplePeopleScreen extends StatelessWidget {
  const SimplePeopleScreen({super.key});

  @override
  Widget build(BuildContext context) => SimpleTheme(
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.peopleTabLabel),
            actions: const [SimpleEmergencyButton(), SimpleSettingsButton()],
          ),
          body: const SocialPeopleTab(heading: SimpleSectionHeader.new),
        ),
      );
}
