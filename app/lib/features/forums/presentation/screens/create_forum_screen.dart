import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/forum_repository.dart';
import '../providers/forum_providers.dart';
import '../../../../core/i18n/l10n_context.dart';

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
        SnackBar(content: Text(context.l10n.signCreateForum)),
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
        SnackBar(content: Text(context.l10n.couldNotCreateForum(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(context.l10n.createForum)),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        children: [
          Text(
            context.l10n.contactNameField,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textPrimary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: TextStyle(color: context.palette.textPrimary),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: context.l10n.eGSundayBreakfast,
              hintStyle: TextStyle(color: context.palette.textTertiary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.descriptionOptional,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textPrimary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            style: TextStyle(color: context.palette.textPrimary),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: context.l10n.whatsThisForumAbout,
              hintStyle: TextStyle(color: context.palette.textTertiary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.youllBeAbleModerate,
            style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.palette.primary),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(context.l10n.create, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
