import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/bike_visibility.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../providers/profile_providers.dart';
import '../../../../core/i18n/l10n_context.dart';

/// Edit the signed-in rider's public profile: display name, nickname, bio,
/// @username, and avatar. Reached from the garage header's user menu.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  /// Shows a lightweight bottom sheet that prompts the user to write their
  /// first bio. Called by the onboarding tour's final (Profile) slide.
  ///
  /// The sheet has a single multi-line bio field and a "Save bio" button.
  /// It is intentionally minimal — full profile editing is still at
  /// `/profile/edit`. Dismissable by dragging down or tapping outside.
  static void showBioPromptSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BioPromptSheet(),
    );
  }

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  String? _localImagePath;
  String? _photoUrl;
  bool _loaded = false;
  bool _saving = false;
  String? _usernameError;
  String _visibility = 'public';
  String _bikesVisibility = kBikesVisibilityPublic;

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _seedFrom(UserProfileEntity? profile) {
    if (_loaded || profile == null) return;
    _displayNameCtrl.text = profile.displayName;
    _nicknameCtrl.text = profile.nickname ?? '';
    _bioCtrl.text = profile.bio ?? '';
    _usernameCtrl.text = profile.username ?? '';
    _photoUrl = profile.photoUrl;
    _visibility = profile.visibility;
    // Normalized: SegmentedButton asserts if `selected` isn't one of its
    // segment values, and an unrecognized stored value means public anyway
    // (see canSeeBikes).
    _bikesVisibility = kBikesVisibilityLevels.contains(profile.bikesVisibility)
        ? profile.bikesVisibility
        : kBikesVisibilityPublic;
    _loaded = true;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile != null) setState(() => _localImagePath = xfile.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() {
      _saving = true;
      _usernameError = null;
    });

    final repo = ref.read(profileRepositoryProvider);
    try {
      String? photoUrl;
      if (_localImagePath != null) {
        photoUrl = await repo.uploadAvatar(uid, File(_localImagePath!));
      }

      final username = _usernameCtrl.text.trim();
      if (username.isNotEmpty) {
        await repo.setUsername(uid: uid, username: username);
      }

      await repo.updateProfile(
        uid: uid,
        displayName: _displayNameCtrl.text.trim(),
        nickname: _nicknameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        photoUrl: photoUrl,
      );
      await repo.setVisibility(uid: uid, visibility: _visibility);
      await repo.setBikesVisibility(uid: uid, bikesVisibility: _bikesVisibility);

      if (!mounted) return;
      context.pop();
    } on UsernameTakenException {
      setState(() => _usernameError = context.l10n.thatUsernameTakenTry);
    } on InvalidUsernameException {
      setState(() => _usernameError = context.l10n.usernameRuleError);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotSaveProfile(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    profileAsync.whenData(_seedFrom);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(context.l10n.editProfile)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      _localImagePath != null
                          ? CircleAvatar(
                              radius: 44,
                              backgroundImage: FileImage(File(_localImagePath!)),
                            )
                          : UserAvatar(
                              photoUrl: _photoUrl,
                              name: _displayNameCtrl.text,
                              radius: 44,
                            ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: context.palette.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _displayNameCtrl,
                style: TextStyle(color: context.palette.textPrimary),
                decoration: InputDecoration(labelText: context.l10n.displayName),
                validator: (v) => v == null || v.trim().isEmpty ? context.l10n.requiredField : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nicknameCtrl,
                style: TextStyle(color: context.palette.textPrimary),
                decoration: InputDecoration(
                    labelText: context.l10n.nickname, hintText: context.l10n.shownCardsFeed),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameCtrl,
                style: TextStyle(color: context.palette.textPrimary),
                decoration: InputDecoration(
                  labelText: context.l10n.usernameField,
                  hintText: 'yourhandle',
                  prefixText: '@',
                  errorText: _usernameError,
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final handle = v.trim();
                  if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(handle)) {
                    return context.l10n.n320LettersNumbers;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioCtrl,
                style: TextStyle(color: context.palette.textPrimary),
                maxLines: 3,
                decoration: InputDecoration(labelText: context.l10n.bio),
              ),
              const SizedBox(height: 20),
              Text(context.l10n.whoCanSeeProfile,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: context.palette.textPrimary)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'public', label: Text(context.l10n.everyone), icon: const Icon(Icons.public, size: 16)),
                  ButtonSegment(
                      value: 'mutual', label: Text(context.l10n.mutuals), icon: const Icon(Icons.people, size: 16)),
                  ButtonSegment(value: 'private', label: Text(context.l10n.onlyMe), icon: const Icon(Icons.lock, size: 16)),
                ],
                selected: {_visibility},
                onSelectionChanged: (s) => setState(() => _visibility = s.first),
              ),
              const SizedBox(height: 20),
              Text(context.l10n.whoCanSeeBikes,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: context.palette.textPrimary)),
              const SizedBox(height: 4),
              Text(context.l10n.garageProfileSeparateFrom,
                  style: TextStyle(fontSize: 11, color: context.palette.textTertiary)),
              const SizedBox(height: 8),
              // 'followers' here, not 'mutual' as above: hiding bikes is about
              // who follows YOU, so a one-way follower qualifies.
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: kBikesVisibilityPublic,
                      label: Text(context.l10n.everyone),
                      icon: const Icon(Icons.public, size: 16)),
                  ButtonSegment(
                      value: kBikesVisibilityFollowers,
                      label: Text(context.l10n.audienceFollowers),
                      icon: const Icon(Icons.group, size: 16)),
                  ButtonSegment(
                      value: kBikesVisibilityPrivate,
                      label: Text(context.l10n.onlyMe),
                      icon: const Icon(Icons.lock, size: 16)),
                ],
                selected: {_bikesVisibility},
                onSelectionChanged: (s) => setState(() => _bikesVisibility = s.first),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(context.l10n.saveChanges),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bio-prompt bottom sheet
// Shown by EditProfileScreen.showBioPromptSheet() at the end of onboarding.
// ─────────────────────────────────────────────────────────────────────────────

class _BioPromptSheet extends ConsumerStatefulWidget {
  const _BioPromptSheet();

  @override
  ConsumerState<_BioPromptSheet> createState() => _BioPromptSheetState();
}

class _BioPromptSheetState extends ConsumerState<_BioPromptSheet> {
  final _bioCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBio() async {
    final bio = _bioCtrl.text.trim();
    if (bio.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid != null) {
        await ProfileRepository().updateProfile(uid: uid, bio: bio);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Icon + heading
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Color(0xFFE91E63), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.tellRidersAboutYourself,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.goodBioGetsMore,
                      style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Bio field
          TextField(
            controller: _bioCtrl,
            autofocus: true,
            maxLines: 3,
            maxLength: 160,
            style: TextStyle(color: context.palette.textPrimary),
            decoration: InputDecoration(
              hintText: context.l10n.eGFzS,
              hintStyle: TextStyle(color: context.palette.textTertiary, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE91E63), width: 2),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.skip, style: TextStyle(color: context.palette.textTertiary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveBio,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(context.l10n.saveBio),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
