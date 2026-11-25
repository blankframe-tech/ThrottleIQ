import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/simple_settings_button.dart';

/// Simple mode Home tab. Placeholder; the home lane (#241) replaces it.
class SimpleHomeScreen extends ConsumerWidget {
  const SimpleHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Scaffold(appBar: AppBar(actions: const [SimpleSettingsButton()]));
}
