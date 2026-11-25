import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple mode ride detail. Placeholder; the ridesbike lane (#242) replaces it.
class SimpleRideDetailScreen extends ConsumerWidget {
  const SimpleRideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const Scaffold(body: SizedBox.shrink());
}
