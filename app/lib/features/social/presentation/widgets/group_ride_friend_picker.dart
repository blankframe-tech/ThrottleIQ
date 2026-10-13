import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../profile/domain/entities/user_profile_entity.dart';
import '../../domain/utilities/group_ride_selection.dart';
import '../../../../core/i18n/l10n_context.dart';

/// Modal sheet that searches riders by @username (or exact email) and lets the
/// rider pick between [kMinGroupRideFriends] and [kMaxGroupRideFriends] of
/// them for a group ride.
///
/// Search behaviour is lifted from the existing "Find riders" sheet in
/// social_screen.dart — same `ProfileRepository.searchByUsername` /
/// `searchByEmail` split on "does this look like an email", same
/// filter-yourself-out step — so there's one search idiom in the app rather
/// than two that drift.
///
/// Pops with the chosen riders, or `null` if the rider backed out. It never
/// pops with an invalid selection: the confirm button is disabled until
/// [validateGroupSelection] returns null.
class GroupRideFriendPickerSheet extends ConsumerStatefulWidget {
  const GroupRideFriendPickerSheet({super.key});

  /// Opens the sheet and resolves to the picked riders, or null on cancel.
  static Future<List<UserProfileEntity>?> show(BuildContext context) {
    return showModalBottomSheet<List<UserProfileEntity>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.background,
      builder: (_) => const GroupRideFriendPickerSheet(),
    );
  }

  @override
  ConsumerState<GroupRideFriendPickerSheet> createState() =>
      _GroupRideFriendPickerSheetState();
}

class _GroupRideFriendPickerSheetState
    extends ConsumerState<GroupRideFriendPickerSheet> {
  final _controller = TextEditingController();

  /// Keyed by uid so a rider matched by two different searches (once by
  /// username, once by email) can't be added twice — the de-dup the brief
  /// asks for is structural here rather than a filtering pass.
  final Map<String, UserProfileEntity> _selected = {};

  List<UserProfileEntity> _results = const [];
  bool _loading = false;

  /// Guards against an older, slower search overwriting a newer one's results
  /// — every keystroke fires a query and Firestore does not promise they come
  /// back in order.
  int _searchSeq = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    final seq = ++_searchSeq;

    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    final repo = ProfileRepository();
    final looksLikeEmail = q.contains('@') && q.contains('.') && !q.startsWith('@');
    List<UserProfileEntity> results;
    try {
      results = looksLikeEmail
          ? await repo.searchByEmail(q)
          : await repo.searchByUsername(q);
    } catch (_) {
      results = const [];
    }
    if (!mounted || seq != _searchSeq) return;

    final myUid = ref.read(currentUserProvider)?.uid;
    setState(() {
      // You can't invite yourself on a group ride — you're already on it.
      _results = results.where((r) => r.uid != myUid).toList();
      _loading = false;
    });
  }

  void _toggle(UserProfileEntity rider) {
    final myUid = ref.read(currentUserProvider)?.uid;
    if (rider.uid == myUid) return;

    if (_selected.containsKey(rider.uid)) {
      setState(() => _selected.remove(rider.uid));
      return;
    }
    if (!canAddAnotherFriend(_selected.length)) {
      // Refuse the 11th *before* it lands in the set, so the counter never
      // flashes "11/10" and the confirm button never has to un-enable itself.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(_problemText(
              context, validateGroupSelection(kMaxGroupRideFriends + 1)!)),
        ));
      return;
    }
    setState(() => _selected[rider.uid] = rider);
  }

  /// Wording for a selection problem. Lives here rather than in
  /// `group_ride_selection.dart` because only a widget has an
  /// `AppLocalizations`; the bound itself still lives in exactly one place.
  ///
  /// Two "too few" strings rather than one with a plural placeholder: the
  /// minimum is 1 today, and "Pick at least 1 riders" is what a single
  /// pluralized string would produce the moment anyone reads it.
  String _problemText(
      BuildContext context, ({GroupSelectionProblem problem, int shortBy}) p) {
    final l10n = context.l10n;
    return switch (p.problem) {
      GroupSelectionProblem.tooMany =>
        l10n.groupRideTooManyFriends(kMaxGroupRideFriends),
      GroupSelectionProblem.tooFew => kMinGroupRideFriends == 1
          ? l10n.groupRidePickAtLeastOne
          : l10n.groupRidePickAtLeastMany(kMinGroupRideFriends, p.shortBy),
    };
  }

  @override
  Widget build(BuildContext context) {
    final problem = validateGroupSelection(_selected.length);

    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.paddingMd,
        right: AppDimensions.paddingMd,
        top: AppDimensions.paddingMd,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.paddingMd,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.rideWithFriends,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _selected.isEmpty
                        ? context.palette.surfaceVariant
                        : context.palette.primary.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(context.shape.radiusFull),
                  ),
                  child: Text(
                    context.l10n.selectedCount(_selected.length, kMaxGroupRideFriends),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _selected.isEmpty
                          ? context.palette.textSecondary
                          : context.palette.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.pickRidersRideStarts(kMinGroupRideFriends, kMaxGroupRideFriends),
              style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: context.palette.textPrimary),
              decoration: InputDecoration(
                hintText: context.l10n.usernameEmail,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _search,
            ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selected.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final rider = _selected.values.elementAt(i);
                    return InputChip(
                      label: Text(rider.bestName),
                      onDeleted: () => setState(() => _selected.remove(rider.uid)),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(child: _buildResults()),
            const SizedBox(height: 8),
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _problemText(context, problem),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                ),
              ),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: problem != null
                    ? null
                    : () => Navigator.of(context).pop(_selected.values.toList()),
                child: Text(
                  _selected.isEmpty
                      ? context.l10n.startGroupRide
                      : context.l10n.startGroupRideWithCount(_selected.length),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: context.palette.primary));
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _controller.text.trim().isEmpty
              ? context.l10n.searchByUsernameEmail
              : context.l10n.noRidersFound,
          style: TextStyle(color: context.palette.textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final rider = _results[i];
        final picked = _selected.containsKey(rider.uid);
        return _RiderPickTile(
          rider: rider,
          selected: picked,
          onTap: () => _toggle(rider),
        );
      },
    );
  }
}

class _RiderPickTile extends StatelessWidget {
  final UserProfileEntity rider;
  final bool selected;
  final VoidCallback onTap;

  const _RiderPickTile({
    required this.rider,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? context.palette.primary.withValues(alpha: 0.08)
          : context.palette.surface,
      borderRadius: BorderRadius.circular(context.shape.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.shape.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.shape.radiusMd),
            border: Border.all(
              color: selected ? context.palette.primary : context.palette.border,
            ),
          ),
          child: Row(
            children: [
              UserAvatar(
                  photoUrl: rider.photoUrl, name: rider.bestName, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rider.bestName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    if (rider.username != null)
                      Text(
                        '@${rider.username}',
                        style: TextStyle(
                            fontSize: 12, color: context.palette.textSecondary),
                      ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? context.palette.primary : context.palette.textTertiary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
