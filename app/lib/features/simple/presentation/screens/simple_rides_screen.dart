import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/simple_settings_button.dart';

/// Simple mode Rides tab. Placeholder; the ridesbike lane (#242) replaces it.
class SimpleRidesScreen extends ConsumerWidget {
  const SimpleRidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Scaffold(appBar: AppBar(actions: const [SimpleSettingsButton()]));
}
