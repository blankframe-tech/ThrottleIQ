import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/emergency_contacts_provider.dart';

/// Settings → Emergency contacts: the "not alerted yet" banner, the list,
/// and the add dialog.
class SettingsEmergencyContactsSection extends ConsumerWidget {
  const SettingsEmergencyContactsSection({super.key});

  /// SharedPreferences flag: the "contacts aren't alerted yet" dialog has
  /// been acknowledged once and never needs showing again.
  static const _contactsAckKey = 'emergency_contacts_not_alerted_ack';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final contacts = ref.watch(emergencyContactsNotifierProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(l10n.emergencyContactsSection,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showContactDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.addAction),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // A warning-colored banner, not fine print: until crash alerts
        // actually send, having contacts here must not read as being
        // protected (grill §3.6.3).
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.palette.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(context.shape.radiusMd),
            border: Border.all(color: context.palette.warning),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: context.palette.warning, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.emergencyContactsNotAlertedBanner,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.emergencyContactsDescription,
          style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
        ),
        const SizedBox(height: 12),
        contacts.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
                child:
                    CircularProgressIndicator(color: context.palette.primary)),
          ),
          error: (e, _) => Text(l10n.emergencyContactsLoadError('$e'),
              style: TextStyle(color: context.palette.danger, fontSize: 13)),
          data: (list) => list.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: Center(
                    child: Text(l10n.emergencyContactsEmpty,
                        style: TextStyle(
                            fontSize: 13,
                            color: context.palette.textSecondary)),
                  ),
                )
              : Column(
                  children: [
                    for (final c in list)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: context.palette.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.palette.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.contact_emergency_outlined,
                                color: context.palette.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: context.palette.textPrimary)),
                                  Text(
                                      c.email == null
                                          ? c.phone
                                          : '${c.phone} · ${c.email}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              context.palette.textSecondary)),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: context.l10n.delete,
                              onPressed: () => ref
                                  .read(emergencyContactsNotifierProvider
                                      .notifier)
                                  .deleteContact(c.id),
                              icon: Icon(Icons.delete_outline,
                                  color: context.palette.textTertiary,
                                  size: 20),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showContactDialog(BuildContext context, WidgetRef ref) async {
    final wasEmpty =
        ref.read(emergencyContactsNotifierProvider).valueOrNull?.isEmpty ??
            true;
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddContactDialog(),
    );
    if (added != true || !wasEmpty || !context.mounted) return;

    // One-time acknowledgement on the rider's first contact — the moment
    // they're most likely to assume that contact will now be told about a
    // crash. See emergencyContactsNotAlertedBanner.
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getBool(_contactsAckKey) ?? false) || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.palette.surface,
        icon: Icon(Icons.warning_amber_rounded,
            color: dialogContext.palette.warning, size: 32),
        title: Text(l10n.emergencyContactsAckTitle,
            style: TextStyle(
                color: dialogContext.palette.textPrimary, fontSize: 18)),
        content: Text(l10n.emergencyContactsAckBody,
            style: TextStyle(color: dialogContext.palette.textSecondary)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.emergencyContactsAckAction),
          ),
        ],
      ),
    );
    await prefs.setBool(_contactsAckKey, true);
  }
}

/// The "Add Emergency Contact" dialog's content, as its own
/// [ConsumerStatefulWidget] rather than `TextEditingController`s created
/// inline in `_showContactDialog` — those were never disposed at all (a
/// small per-open leak, not a crash: unlike forum_thread_screen.dart's
/// "New post" sheet, this dialog never called `.dispose()` in the first
/// place, so it never hit the "used after disposed" race). Fixed with the
/// same State-owned-controllers pattern used there, since it's the
/// structurally correct way to own a TextEditingController's lifecycle
/// regardless of which specific failure mode a given ad hoc version hits.
class _AddContactDialog extends ConsumerStatefulWidget {
  const _AddContactDialog();

  @override
  ConsumerState<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends ConsumerState<_AddContactDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) return;
    final email = _emailCtrl.text.trim();
    ref.read(emergencyContactsNotifierProvider.notifier).addContact(
          name: name,
          phone: phone,
          email: email.isEmpty ? null : email,
        );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: context.palette.surface,
      title: Text(l10n.addEmergencyContactTitle,
          style: TextStyle(color: context.palette.textPrimary, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: context.palette.textPrimary),
            decoration: InputDecoration(labelText: l10n.contactNameField),
          ),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: context.palette.textPrimary),
            decoration: InputDecoration(labelText: l10n.contactPhoneField),
          ),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: context.palette.textPrimary),
            decoration:
                InputDecoration(labelText: l10n.contactEmailFieldOptional),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelAction),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(l10n.addAction),
        ),
      ],
    );
  }
}
