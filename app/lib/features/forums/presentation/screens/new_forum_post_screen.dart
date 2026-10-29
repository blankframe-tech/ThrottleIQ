import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../data/repositories/forum_repository.dart';
import '../../domain/entities/forum_post_entity.dart';
import '../../domain/forum_author_bike.dart';
import '../../domain/forum_directory.dart';
import '../providers/forum_providers.dart';
import '../widgets/forum_post_badges.dart';
import '../widgets/forum_post_images.dart';
import '../widgets/forum_topic_style.dart';

/// Opens the new-post page. [group] starts ticked in the share step ("Ask
/// owners", a forum's own "New post"); [attachment] is a shared ride or
/// maintenance visit.
void openNewForumPost(BuildContext context,
    {String? group, ForumAttachment? attachment}) {
  context.push(
    group == null ? '/forums/new' : '/forums/new?group=$group',
    extra: attachment,
  );
}

/// Write first, pick groups last (owner, 2026-10-25): title, what's going
/// on, photos and the bike byline on a full page; "Share" then asks which
/// groups (up to [kForumPostMaxGroups]). Every post is in the All Riders
/// feed whatever is picked, so picking nothing is fine.
class NewForumPostScreen extends ConsumerStatefulWidget {
  const NewForumPostScreen({super.key, this.initialGroup, this.attachment});

  final String? initialGroup;
  final ForumAttachment? attachment;

  @override
  ConsumerState<NewForumPostScreen> createState() => _NewForumPostScreenState();
}

class _NewForumPostScreenState extends ConsumerState<NewForumPostScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _submitting = false;
  // A shared maintenance visit is usually a "here's what I did" write-up,
  // so it starts as a DIY guide; the rider can still change it.
  late ForumPostType _postType =
      widget.attachment?.kind == ForumAttachmentKind.maintenance
          ? ForumPostType.diyGuide
          : ForumPostType.general;
  late ForumAttachment? _attachment = widget.attachment;
  bool _attachBike = true;
  // Local paths of photos picked for the post; uploaded on submit.
  final List<String> _photoPaths = [];
  // Only set once the rider has tried to share (issues §54).
  bool _titleError = false;
  bool _bodyError = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photoPaths.length >= kForumPostMaxImages) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.palette.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined,
                  color: sheetContext.palette.primary),
              title: Text(sheetContext.l10n.takeAPhoto,
                  style: TextStyle(color: sheetContext.palette.textPrimary)),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: sheetContext.palette.primary),
              title: Text(sheetContext.l10n.chooseFromGallery,
                  style: TextStyle(color: sheetContext.palette.textPrimary)),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picker = ImagePicker();
      final remaining = kForumPostMaxImages - _photoPaths.length;
      final List<XFile> picked;
      if (source == ImageSource.gallery && remaining > 1) {
        picked = await picker.pickMultiImage(
            imageQuality: 80,
            maxWidth: 2048,
            maxHeight: 2048,
            limit: remaining);
      } else {
        final one = await picker.pickImage(
            source: source, imageQuality: 80, maxWidth: 2048, maxHeight: 2048);
        picked = [if (one != null) one];
      }
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _photoPaths.addAll(picked.take(remaining).map((x) => x.path));
      });
    } catch (e, st) {
      // issues §101.P7: log the raw exception; riders get plain text.
      reportNonFatal(e, st, reason: 'image picker');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenCamera)),
      );
    }
  }

  /// The forum doc a post's home must exist for (createPost bumps its
  /// count). Topic boards and All Riders are created on first use.
  Future<String> _ensureHome(ForumRepository repo, String id) async {
    final topic = id == kAllRidersForumId
        ? kAllRidersTopic
        : TopicBoard.values.where((b) => b.slug == id).firstOrNull?.topic;
    if (topic == null) return id;
    return (await repo.getOrCreateGeneralForum(topic: topic)).id;
  }

  Future<void> _share() async {
    if (_submitting) return;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() {
        _titleError = title.isEmpty;
        _bodyError = body.isEmpty;
      });
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(context.shape.radiusLg)),
      ),
      builder: (_) => _ShareGroupsSheet(
        initial: [if (widget.initialGroup case final g?) g],
        attachment: _attachment,
      ),
    );
    if (picked == null || !mounted) return;

    final bike = _attachBike ? ref.read(activeBikeProvider) : null;
    final authorBike = bike == null ? null : authorBikeLabel(bike);
    var (home, alsoIn) = forumPostTargets(picked);

    setState(() => _submitting = true);
    final String postId;
    final List<String> imageUrls;
    try {
      final repo = ForumRepository();
      try {
        imageUrls = [
          for (final path in _photoPaths)
            await repo.uploadPostPhoto(user.uid, File(path)),
        ];
      } catch (e) {
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n
                  .forumPhotoUploadFailed(mapFirestoreError(e, context.l10n)))),
        );
        return;
      }
      home = await _ensureHome(repo, home);
      postId = await repo.createPost(
        forumId: home,
        userId: user.uid,
        userName: user.displayName ?? 'Rider',
        userPhotoUrl: user.photoURL ?? '',
        title: title,
        body: body,
        postType: _postType,
        authorBike: authorBike,
        attachment: _attachment,
        imageUrls: imageUrls,
        alsoIn: alsoIn,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirestoreError(e, context.l10n))),
      );
      return;
    }
    if (!mounted) return;
    final post = ForumPostEntity(
      id: postId,
      forumId: home,
      userId: user.uid,
      userName: user.displayName ?? 'Rider',
      userPhotoUrl: user.photoURL ?? '',
      title: title,
      body: body,
      createdAt: DateTime.now(),
      postType: _postType,
      authorBike: authorBike,
      attachment: _attachment,
      imageUrls: imageUrls,
    );
    // Lists already on screen get the post at once (not an invalidate, see
    // issues §54); the rest load it when opened.
    for (final id in {home, kAllRidersForumId, ...alsoIn}) {
      if (ref.exists(forumPostsNotifierProvider(id))) {
        ref.read(forumPostsNotifierProvider(id).notifier).addPost(post);
      }
    }
    ref.invalidate(forumsForGarageProvider);
    ref.invalidate(forumsPulseFeedProvider);
    if (widget.initialGroup != null) {
      context.pop(); // back to the forum it was opened from
    } else {
      context.pushReplacement('/forums/$home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bike = ref.watch(activeBikeProvider);
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: Text(context.l10n.newPost)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.paddingMd,
            8,
            AppDimensions.paddingMd,
            MediaQuery.viewInsetsOf(context).bottom + AppDimensions.paddingSm,
          ),
          child: ElevatedButton.icon(
            key: const Key('post_share'),
            style: ElevatedButton.styleFrom(backgroundColor: palette.primary),
            onPressed: _submitting ? null : _share,
            icon: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Icon(Icons.send_outlined, color: Colors.white),
            label: Text(context.l10n.forumShare,
                style: const TextStyle(color: Colors.white)),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        children: [
          TextField(
            key: const Key('post_title'),
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: palette.textPrimary),
            onChanged: (_) {
              if (_titleError) setState(() => _titleError = false);
            },
            decoration: InputDecoration(
              hintText: context.l10n.title,
              errorText: _titleError ? context.l10n.titleRequired : null,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('post_body'),
            controller: _bodyController,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: palette.textPrimary),
            minLines: 5,
            maxLines: 12,
            onChanged: (_) {
              if (_bodyError) setState(() => _bodyError = false);
            },
            decoration: InputDecoration(
              hintText: context.l10n.whatsGoing,
              errorText:
                  _bodyError ? context.l10n.saySomethingBeforePosting : null,
            ),
          ),
          if (_attachment != null) ...[
            const SizedBox(height: 12),
            ForumAttachmentCard(
              attachment: _attachment!,
              viewerIsAuthor: true,
              authorName: '',
              onRemove: () => setState(() => _attachment = null),
            ),
          ],
          const SizedBox(height: 12),
          if (_photoPaths.isNotEmpty) ...[
            ForumPickedPhotos(
              paths: _photoPaths,
              onRemove: (i) => setState(() => _photoPaths.removeAt(i)),
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('post_add_photo'),
              onPressed:
                  _submitting || _photoPaths.length >= kForumPostMaxImages
                      ? null
                      : _pickPhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(context.l10n
                  .forumAddPhotos(_photoPaths.length, kForumPostMaxImages)),
            ),
          ),
          if (bike != null)
            SwitchListTile(
              key: const Key('post_attach_bike'),
              contentPadding: EdgeInsets.zero,
              value: _attachBike,
              onChanged: (v) => setState(() => _attachBike = v),
              title: Text(context.l10n.forumAttachMyBike,
                  style: TextStyle(fontSize: 14, color: palette.textPrimary)),
              subtitle: Text(authorBikeLabel(bike),
                  style: TextStyle(fontSize: 12, color: palette.textSecondary)),
            )
          else
            Text(
              context.l10n.forumNoBikeToAttach,
              style: TextStyle(fontSize: 12, color: palette.textTertiary),
            ),
          const SizedBox(height: 12),
          Text(
            context.l10n.forumPostTypeLabel,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final type in [
                ForumPostType.general,
                ForumPostType.troubleshoot,
                ForumPostType.diyGuide,
                ForumPostType.gearReview,
              ])
                ChoiceChip(
                  key: Key('post_type_${type.name}'),
                  avatar: Icon(forumPostTypeIcon(type), size: 16),
                  label: Text(forumPostTypeLabel(context.l10n, type)),
                  selected: _postType == type,
                  onSelected: (_) => setState(() => _postType = type),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Share to groups": All Riders always, plus up to [kForumPostMaxGroups]
/// of the rider's own groups (garage and followed, already known to Pulse,
/// so no extra reads) and the topic boards. Pops the picked forum ids.
class _ShareGroupsSheet extends ConsumerStatefulWidget {
  const _ShareGroupsSheet({required this.initial, this.attachment});

  final List<String> initial;
  final ForumAttachment? attachment;

  @override
  ConsumerState<_ShareGroupsSheet> createState() => _ShareGroupsSheetState();
}

class _ShareGroupsSheetState extends ConsumerState<_ShareGroupsSheet> {
  late final List<String> _picked = [...widget.initial];

  void _toggle(String id, bool on) => setState(() {
        if (!on) {
          _picked.remove(id);
        } else if (_picked.length < kForumPostMaxGroups) {
          _picked.add(id);
        }
      });

  Widget _tile(String id, String name, Widget icon) {
    final on = _picked.contains(id);
    final full = _picked.length >= kForumPostMaxGroups;
    return CheckboxListTile(
      key: Key('share_group_$id'),
      contentPadding: EdgeInsets.zero,
      secondary: icon,
      value: on,
      onChanged: on || !full ? (v) => _toggle(id, v ?? false) : null,
      title: Text(name, style: TextStyle(color: context.palette.textPrimary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final sourcesAsync = ref.watch(pulseSourcesProvider);
    final sources = sourcesAsync.valueOrNull ?? PulseSources.empty;
    final topicIds = {for (final b in TopicBoard.values) b.slug};
    final yours = [
      for (final id in widget.initial)
        if (!sources.forumIds.contains(id) && !topicIds.contains(id)) id,
      for (final id in sources.forumIds)
        if (!topicIds.contains(id) && id != kAllRidersForumId) id,
    ];
    // A maintenance visit most naturally belongs on the Wrench Bench.
    final boards = [...TopicBoard.values]..sort((a, b) {
        if (widget.attachment?.kind == ForumAttachmentKind.maintenance) {
          if (a == TopicBoard.wrenchBench) return -1;
          if (b == TopicBoard.wrenchBench) return 1;
        }
        return a.index.compareTo(b.index);
      });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, controller) => SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(AppDimensions.paddingMd,
                    AppDimensions.paddingMd, AppDimensions.paddingMd, 0),
                children: [
                  Text(
                    l10n.forumShareToGroupsTitle,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.forumShareAllRidersNote(kForumPostMaxGroups),
                    style:
                        TextStyle(fontSize: 13, color: palette.textSecondary),
                  ),
                  CheckboxListTile(
                    key: const Key('share_group_all_riders'),
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(Icons.public, color: palette.primary),
                    value: true,
                    onChanged: null,
                    title: Text(l10n.allRidersGroup,
                        style: TextStyle(color: palette.textPrimary)),
                  ),
                  if (sourcesAsync.isLoading)
                    Center(
                        child:
                            CircularProgressIndicator(color: palette.primary))
                  else if (yours.isNotEmpty) ...[
                    Divider(color: palette.border),
                    Text(l10n.forumShareYourGroups,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: palette.textSecondary)),
                    for (final id in yours)
                      _tile(
                        id,
                        sources.names[id] ??
                            ref
                                .watch(forumByIdProvider(id))
                                .valueOrNull
                                ?.displayName ??
                            id,
                        Icon(
                          sources.garageForumIds.contains(id)
                              ? Icons.two_wheeler
                              : Icons.forum_outlined,
                          color: palette.primary,
                        ),
                      ),
                  ],
                  Divider(color: palette.border),
                  Text(l10n.topicBoards,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: palette.textSecondary)),
                  for (final board in boards)
                    _tile(
                      board.slug,
                      topicBoardTitle(l10n, board),
                      Icon(topicBoardIcon(board), color: Color(board.accent)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.forumShareCount(_picked.length, kForumPostMaxGroups),
                      key: const Key('share_group_count'),
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  ),
                  ElevatedButton(
                    key: const Key('share_groups_confirm'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary),
                    onPressed: () => Navigator.of(context).pop(_picked),
                    child: Text(l10n.forumShare,
                        style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
