import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Route List Screen - shows saved routes and allows re-riding
///
/// Features:
/// - List of saved routes
/// - Route details (distance, times ridden)
/// - Re-ride button (loads route on map)
/// - Share route functionality
/// - Delete route option
class RouteListScreen extends ConsumerStatefulWidget {
  const RouteListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends ConsumerState<RouteListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Routes'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.explore),
            onPressed: () {
              // Navigate to public routes
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No saved routes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Save routes from completed rides',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate to explore public routes
              },
              child: const Text('Explore Public Routes'),
            ),
          ],
        ),
      ),
    );
  }
}
