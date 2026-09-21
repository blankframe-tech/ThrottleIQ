import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// `context.l10n.someKey` — shorthand for `AppLocalizations.of(context)`,
/// alongside `context.palette` / `context.shape` (see
/// `core/theme/app_theme_context.dart`).
///
/// Like those, call it from `build` or a builder: it registers the widget as a
/// dependent so it is rebuilt when the language changes. Inside a dialog or
/// sheet `builder:`, use that builder's own context, not the caller's.
extension AppL10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
