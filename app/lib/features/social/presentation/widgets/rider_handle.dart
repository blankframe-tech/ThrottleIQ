import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/presentation/providers/profile_providers.dart';

/// A shared ride's author as `@username`. The ride doc only snapshots the
/// rider's full name, so the handle is read from their profile (one cached
/// stream per uid, however many cards they have). Falls back to [fallback]
/// for a rider with no username or an unreadable profile; blank while loading
/// so the full name never flashes first.
class RiderHandle extends ConsumerWidget {
  final String uid;
  final String fallback;
  final TextStyle? style;

  const RiderHandle(
      {super.key, required this.uid, required this.fallback, this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider(uid));
    final username = profile.valueOrNull?.username;
    final text = (username != null && username.isNotEmpty)
        ? '@$username'
        : (profile.isLoading ? '' : fallback);
    return Text(text,
        maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
  }
}
