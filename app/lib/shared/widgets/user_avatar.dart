import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
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
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.15),
      backgroundImage: hasPhoto ? CachedNetworkImageProvider(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              initialsFrom(name),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                fontSize: radius * 0.7,
              ),
            ),
    );
  }
}
