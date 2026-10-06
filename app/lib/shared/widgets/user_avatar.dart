import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme_context.dart';
import '../../core/utils/initials.dart';

/// A rider's avatar: their photo when set, otherwise a GitHub-style circle
/// with their initials — the fallback used across profiles, forum
/// posts/replies, and feed cards.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const UserAvatar({super.key, this.photoUrl, required this.name, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: context.palette.primary.withValues(alpha: 0.15),
      child: Text(
        initialsFrom(name),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: context.palette.primary,
          fontSize: radius * 0.7,
        ),
      ),
    );

    if (!hasPhoto) {
      return fallback;
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: photoUrl!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => fallback,
      ),
    );
  }
}
