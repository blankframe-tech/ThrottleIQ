import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/forum_repository.dart';
import '../providers/forum_providers.dart';

/// "Create a forum" — a rider names their own discussion board (route
/// `/forums/create`). The creator becomes its first maintainer, so they can
/// moderate posts in it from the moment it exists.
class CreateForumScreen extends ConsumerStatefulWidget {
  const CreateForumScreen({super.key});

  @override
  ConsumerState<CreateForumScreen> createState() => _CreateForumScreenState();
}

class _CreateForumScreenState extends ConsumerState<CreateForumScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _submitting) return;

    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to create a forum.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final forum = await ForumRepository().createCustomForum(
        name: name,
        description: _descriptionController.text.trim(),
        userId: uid,
      );
      if (!mounted) return;
      // The new forum belongs at the top of the discovery list.
      ref.invalidate(customForumsProvider);
      context.pushReplacement('/forums/${forum.id}');
    } on StateError catch (e) {
      // Name collision — the rider needs to pick another one.
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create the forum: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create a forum')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        children: [
          Text(
            'Name',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: TextStyle(color: AppColors.textPrimary),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'e.g. Sunday Breakfast Rides',
              hintStyle: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Description (optional)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            style: TextStyle(color: AppColors.textPrimary),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "What's this forum about?",
              hintStyle: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "You'll be able to moderate posts here and add other riders as maintainers.",
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
