import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import 'forums_hubs_view.dart';
import 'forums_pulse_view.dart';

/// Which lens the Forums tab shows.
enum ForumsLens { pulse, hubs }

/// Forums tab inside SocialScreen — "The Pit Wall". Two lenses:
///
///  * **Pulse** ([ForumsPulseView]): recent discussions across the rider's
///    garage and followed forums, as a feed.
///  * **Hubs** ([ForumsHubsView]): the directory — garage hero cards, brand
///    paddocks, topic boards, rider clubs.
///
/// Both stay mounted (IndexedStack) so flipping lenses keeps scroll position
/// and costs no re-reads. Search is the Social AppBar's ([onOpenSearch]);
/// this tab no longer carries a second search box.
class ForumsHomeScreen extends StatefulWidget {
  final VoidCallback? onOpenSearch;
  const ForumsHomeScreen({super.key, this.onOpenSearch});

  @override
  State<ForumsHomeScreen> createState() => _ForumsHomeScreenState();
}

class _ForumsHomeScreenState extends State<ForumsHomeScreen> {
  ForumsLens _lens = ForumsLens.pulse;
  bool _hubsVisited = false;

  void _show(ForumsLens lens) => setState(() {
        _lens = lens;
        if (lens == ForumsLens.hubs) _hubsVisited = true;
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingMd, AppDimensions.paddingMd, AppDimensions.paddingMd, 4),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ForumsLens>(
              key: const Key('forums_lens_toggle'),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: context.palette.primary.withValues(alpha: 0.16),
                selectedForegroundColor: context.palette.primary,
                foregroundColor: context.palette.textSecondary,
              ),
              segments: [
                ButtonSegment(
                  value: ForumsLens.pulse,
                  icon: const Icon(Icons.bolt, size: 18),
                  label: Text(context.l10n.forumPulse),
                ),
                ButtonSegment(
                  value: ForumsLens.hubs,
                  icon: const Icon(Icons.sports_score, size: 18),
                  label: Text(context.l10n.forumHubs),
                ),
              ],
              selected: {_lens},
              onSelectionChanged: (s) => _show(s.first),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _lens.index,
            children: [
              ForumsPulseView(
                onExploreHubs: () => _show(ForumsLens.hubs),
              ),
              // Built on first visit only, so a rider who never leaves Pulse
              // never pays for the directory's stats read.
              if (_hubsVisited)
                ForumsHubsView(onOpenSearch: widget.onOpenSearch)
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}
