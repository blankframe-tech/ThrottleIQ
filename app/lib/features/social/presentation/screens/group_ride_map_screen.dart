import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Group Ride Live Map Screen - shows all members' positions in real-time
///
/// Features:
/// - Live map with member positions
/// - Member list with distance to creator
/// - Regroup alert (if member > 5km behind)
/// - Ride control buttons (start/end)
/// - Member status indicators
class GroupRideMapScreen extends ConsumerStatefulWidget {
  final String groupRideId;

  const GroupRideMapScreen({
    Key? key,
    required this.groupRideId,
  }) : super(key: key);

  @override
  ConsumerState<GroupRideMapScreen> createState() =>
      _GroupRideMapScreenState();
}

class _GroupRideMapScreenState extends ConsumerState<GroupRideMapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Ride'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Live map
          Expanded(
            child: Container(
              color: Colors.grey[300],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Live map will render here',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Members list
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Members (0)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'No members tracking',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Control buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Ride'),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End Ride'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
