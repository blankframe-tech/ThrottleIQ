import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../providers/profile_providers.dart';

/// Edit the signed-in rider's public profile: display name, nickname, bio,
/// @username, and avatar. Reached from the garage header's user menu.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

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

      if (!mounted) return;
      context.pop();
    } on UsernameTakenException catch (e) {
      setState(() => _usernameError = e.toString());
    } on InvalidUsernameException catch (e) {
      setState(() => _usernameError = e.toString());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Edit Profile')),
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
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
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
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nicknameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Nickname', hintText: 'Shown on cards & feed'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'yourhandle',
                  prefixText: '@',
                  errorText: _usernameError,
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final handle = v.trim();
                  if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(handle)) {
                    return '3-20 letters, numbers or underscore';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Bio'),
              ),
              const SizedBox(height: 20),
              const Text('Who can see my profile',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'public', label: Text('Everyone'), icon: Icon(Icons.public, size: 16)),
                  ButtonSegment(
                      value: 'mutual', label: Text('Mutuals'), icon: Icon(Icons.people, size: 16)),
                  ButtonSegment(value: 'private', label: Text('Only me'), icon: Icon(Icons.lock, size: 16)),
                ],
                selected: {_visibility},
                onSelectionChanged: (s) => setState(() => _visibility = s.first),
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
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
