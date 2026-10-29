import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/services/public_live_link_setting.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Settings → Privacy & Safety: the password-protected `/r/@handle` link
/// (issues §90.D7). Off by default; turning it on asks for the password.
/// Persisted by [PublicLiveLinkSetting], read by LiveSessionCoordinator.
class SettingsPublicLiveLinkTile extends ConsumerStatefulWidget {
  const SettingsPublicLiveLinkTile({super.key});

  @override
  ConsumerState<SettingsPublicLiveLinkTile> createState() =>
      _SettingsPublicLiveLinkTileState();
}

class _SettingsPublicLiveLinkTileState
    extends ConsumerState<SettingsPublicLiveLinkTile> {
  bool _enabled = false;

  /// Asks for a password and turns the link on with it (or changes it).
  /// Cancelling leaves the setting as it was.
  Future<void> _setPassword() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _LinkPasswordDialog(),
    );
    if (password == null) return;
    await PublicLiveLinkSetting.enable(uid: uid, password: password);
    if (mounted) setState(() => _enabled = true);
  }

  @override
  void initState() {
    super.initState();
    PublicLiveLinkSetting.isEnabled().then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.link, color: context.palette.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.publicLiveLinkTitle,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary)),
                const SizedBox(height: 2),
                Text(context.l10n.publicLiveLinkDesc,
                    style: TextStyle(
                        fontSize: 12, color: context.palette.textSecondary)),
                if (_enabled)
                  TextButton(
                    onPressed: _setPassword,
                    child: Text(context.l10n.publicLiveLinkChangePassword),
                  ),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: (v) async {
              if (v) return _setPassword();
              setState(() => _enabled = false);
              await PublicLiveLinkSetting.disable();
            },
          ),
        ],
      ),
    );
  }
}

class _LinkPasswordDialog extends StatefulWidget {
  const _LinkPasswordDialog();

  @override
  State<_LinkPasswordDialog> createState() => _LinkPasswordDialogState();
}

class _LinkPasswordDialogState extends State<_LinkPasswordDialog> {
  final _controller = TextEditingController();
  bool _tooShort = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    if (text.length < PublicLiveLinkSetting.minPasswordLength) {
      setState(() => _tooShort = true);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.palette.surface,
      title: Text(context.l10n.publicLiveLinkPasswordTitle,
          style: TextStyle(color: context.palette.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.publicLiveLinkPasswordBody,
              style: TextStyle(color: context.palette.textSecondary)),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.l10n.password,
              errorText: _tooShort
                  ? context.l10n.publicLiveLinkPasswordTooShort
                  : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancelAction),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.l10n.publicLiveLinkSave),
        ),
      ],
    );
  }
}
