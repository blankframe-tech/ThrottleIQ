import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/group_ride_repository.dart';
import '../../domain/utilities/group_ride_join_code.dart';
import '../providers/group_ride_providers.dart';

/// Modal sheet for the code half of "Ride with friends" — the door in for a
/// rider nobody has invited yet, e.g. someone met at a fuel stop mid-ride.
/// See `group_ride_join_code.dart` for why this is a shared code rather than
/// a GPS-radius discovery feed.
///
/// Pops with the joined ride's id on success, or `null` on cancel — same
/// shape as [GroupRideFriendPickerSheet.show] popping with picked riders, so
/// both doors resolve to "here's what to navigate to next" for the caller.
class JoinGroupRideByCodeSheet extends ConsumerStatefulWidget {
  const JoinGroupRideByCodeSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => const JoinGroupRideByCodeSheet(),
    );
  }

  @override
  ConsumerState<JoinGroupRideByCodeSheet> createState() =>
      _JoinGroupRideByCodeSheetState();
}

class _JoinGroupRideByCodeSheetState
    extends ConsumerState<JoinGroupRideByCodeSheet> {
  final _controller = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final l10n = AppLocalizations.of(context);
    final code = _controller.text;
    if (!looksLikeGroupRideJoinCode(code)) {
      setState(() => _error = l10n.joinRideCodeInvalidFormat);
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final groupRideId =
          await ref.read(groupRideRepositoryProvider).joinByCode(
                code: code,
                userId: user.uid,
                userName: (user.displayName ?? '').trim().isEmpty
                    ? 'Rider'
                    : user.displayName!.trim(),
                userPhotoUrl: user.photoURL ?? '',
              );
      if (!mounted) return;
      Navigator.of(context).pop(groupRideId);
    } on GroupRideJoinException catch (e) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _error = l10n.joinRideGenericError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.paddingMd,
        right: AppDimensions.paddingMd,
        top: AppDimensions.paddingMd,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.paddingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.joinRideByCodeTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.joinRideByCodeSubtitle,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: kJoinCodeLength + 2, // tolerate a stray space or two
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: l10n.joinRideCodeHint,
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _joining ? null : _join,
              child: _joining
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.surface),
                    )
                  : Text(l10n.joinRideAction),
            ),
          ),
        ],
      ),
    );
  }
}
