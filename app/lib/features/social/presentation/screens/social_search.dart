// AppBar search (riders + forums) for SocialScreen — split out of
// social_screen.dart (issues §90.B7); shares its imports and privates.
part of 'social_screen.dart';

/// Combined rider + forum search, opened from the AppBar's search icon.
/// Each group loads and fails independently — a forum-search error shouldn't
/// hide riders that came back fine.
class _SocialSearchDelegate extends SearchDelegate<void> {
  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = super.appBarTheme(context);
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: context.palette.surface,
        foregroundColor: context.palette.textPrimary,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        hintStyle: TextStyle(color: context.palette.textTertiary),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: context.l10n.close,
            icon: const Icon(Icons.close),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        tooltip: context.l10n.close,
        icon: const BackButtonIcon(),
        onPressed: () => close(context, null),
      );

  /// Submitting searches immediately.
  @override
  Widget buildResults(BuildContext context) => _SearchResults(query: query);

  /// Typing is debounced (issues §90.A7): `buildSuggestions` runs on every
  /// keystroke, and used to fire a rider query per character.
  @override
  Widget buildSuggestions(BuildContext context) =>
      _DebouncedSearchResults(query: query);
}

/// [_SearchResults] for the last query that stayed unchanged for
/// [_searchDebounce].
class _DebouncedSearchResults extends StatefulWidget {
  final String query;
  const _DebouncedSearchResults({required this.query});

  @override
  State<_DebouncedSearchResults> createState() => _DebouncedSearchResultsState();
}

class _DebouncedSearchResultsState extends State<_DebouncedSearchResults> {
  late String _settled = widget.query;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant _DebouncedSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query == oldWidget.query) return;
    _timer?.cancel();
    if (widget.query.trim().isEmpty) {
      _settled = widget.query;
      return;
    }
    _timer = Timer(_searchDebounce, () {
      if (mounted) setState(() => _settled = widget.query);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SearchResults(query: _settled);
}

class _SearchResults extends ConsumerWidget {
  final String query;
  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProvider)?.uid;
    final ridersAsync = ref.watch(_riderSearchProvider(query));
    final forumsAsync = ref.watch(_forumSearchProvider(query));

    // Never offer to follow yourself.
    final riders = (ridersAsync.valueOrNull ?? const <UserProfileEntity>[])
        .where((r) => r.uid != myUid)
        .toList();
    final forums = forumsAsync.valueOrNull ?? const <ForumEntity>[];

    if (query.trim().isEmpty) return const SizedBox.shrink();

    final stillLoading = ridersAsync.isLoading || forumsAsync.isLoading;
    if (!stillLoading && riders.isEmpty && forums.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          child: Text(
            context.l10n.nothingFoundTryUsername(query),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      children: [
        EditorialLabel(context.l10n.ridersLabel),
        const SizedBox(height: 10),
        if (ridersAsync.isLoading)
          const _SectionSpinner()
        else if (ridersAsync.hasError)
          _SectionMessage(context.l10n.couldntSearchRiders(ridersAsync.error ?? ''))
        else if (riders.isEmpty)
          _SectionMessage(context.l10n.noRidersMatchThat)
        else
          for (final rider in riders) ...[
            RiderResultTile(rider: rider),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 16),
        EditorialLabel(context.l10n.forums),
        const SizedBox(height: 10),
        if (forumsAsync.isLoading)
          const _SectionSpinner()
        else if (forumsAsync.hasError)
          _SectionMessage(context.l10n.couldntSearchForums(forumsAsync.error ?? ''))
        else if (forums.isEmpty)
          _SectionMessage(context.l10n.noForumsMatchThat)
        else
          for (final forum in forums) ...[
            _ForumResultTile(forum: forum),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _SectionSpinner extends StatelessWidget {
  const _SectionSpinner();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child:
            Center(child: CircularProgressIndicator(color: context.palette.primary)),
      );
}

class _SectionMessage extends StatelessWidget {
  final String text;
  const _SectionMessage(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
      );
}

class _ForumResultTile extends StatelessWidget {
  final ForumEntity forum;
  const _ForumResultTile({required this.forum});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/forums/${forum.id}'),
      borderRadius: BorderRadius.circular(context.shape.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(context.shape.radiusMd),
          border: Border.all(color: context.palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.palette.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.forum_outlined,
                  color: context.palette.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(forum.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.palette.textPrimary)),
                  Text(
                      context.l10n.followersPosts(forum.followerCount, forum.postCount),
                      style: TextStyle(
                          fontSize: 12, color: context.palette.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.palette.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
