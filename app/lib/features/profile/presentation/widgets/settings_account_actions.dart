import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Settings footer: Sign out and Delete account (Apple Guideline 5.1.1(v)).
class SettingsAccountActions extends ConsumerWidget {
  const SettingsAccountActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            try {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/auth/login');
            } on Exception catch (e) {
              debugPrint('signOut failed: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.signOutFailed),
                    backgroundColor: context.palette.danger,
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.logout, size: 18),
          label: Text(l10n.signOutAction),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: context.palette.textSecondary,
            side: BorderSide(color: context.palette.border),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _confirmDeleteAccount(context, ref),
          icon: const Icon(Icons.delete_forever, size: 18),
          label: Text(context.l10n.deleteAccount),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: context.palette.danger,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: dialogCtx.palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dialogCtx.palette.border),
        ),
        title: Text(
          dialogCtx.l10n.deleteAccountQuestion,
          style: TextStyle(
            color: dialogCtx.palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          dialogCtx.l10n.thisActionIrreversibleAll,
          style: TextStyle(
            color: dialogCtx.palette.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(dialogCtx.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: dialogCtx.palette.danger,
            ),
            child: Text(dialogCtx.l10n.deletePermanently),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.deletingAccount)),
      );
      await _deleteAccountWithReauth(context, ref);
    }
  }

  /// Deletes the account; on `requires-recent-login` asks the rider to
  /// re-prove their identity (issues §101.A1) and retries exactly once.
  /// Raw exception text is never shown (issues §101.A4).
  Future<void> _deleteAccountWithReauth(
      BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final l10n = context.l10n;
    final danger = context.palette.danger;
    void fail(String message) => messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: danger));

    String deleteFailure(Object e) {
      debugPrint('deleteAccount failed: $e');
      return e is firebase_auth.FirebaseAuthException &&
              e.code == 'network-request-failed'
          ? l10n.deleteAccountOffline
          : l10n.deleteAccountFailed;
    }

    try {
      try {
        await auth.deleteAccount();
      } on firebase_auth.FirebaseAuthException catch (e) {
        if (e.code != 'requires-recent-login') rethrow;
        if (!context.mounted) return;
        final isPasswordUser = ref
                .read(firebaseAuthProvider)
                .currentUser
                ?.providerData
                .any((p) => p.providerId == 'password') ??
            false;
        String? password;
        if (isPasswordUser) {
          password = await _askPassword(context);
          if (password == null) return; // cancelled — nothing was deleted
        }
        try {
          if (!await auth.reauthenticate(password: password)) return;
        } on firebase_auth.FirebaseAuthException catch (re) {
          debugPrint('reauthenticate failed: ${re.code}');
          fail(re.code == 'wrong-password' || re.code == 'invalid-credential'
              ? l10n.reauthWrongPassword
              : re.code == 'network-request-failed'
                  ? l10n.deleteAccountOffline
                  : l10n.reauthFailed);
          return;
        }
        await auth.deleteAccount();
      }
      router.go('/auth/login');
    } on Exception catch (e) {
      fail(deleteFailure(e));
    }
  }

  Future<String?> _askPassword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.palette.surface,
        title: Text(ctx.l10n.reauthRequiredTitle,
            style: TextStyle(color: ctx.palette.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ctx.l10n.reauthRequiredBody,
                style: TextStyle(color: ctx.palette.textSecondary)),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: ctx.l10n.password),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: FilledButton.styleFrom(backgroundColor: ctx.palette.danger),
            child: Text(ctx.l10n.deletePermanently),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}
