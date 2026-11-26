import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../poi_directory/domain/place_directions.dart';
import '../../../poi_directory/presentation/providers/places_provider.dart';
import '../../../poi_directory/presentation/widgets/place_launch_actions.dart';
import '../../../profile/domain/entities/emergency_contact_entity.dart';
import '../../../profile/presentation/providers/emergency_contacts_provider.dart';
import '../../../profile/presentation/widgets/settings_emergency_contacts_section.dart';

/// The SMS app at [phone] with [body] (which gets a Google Maps link to
/// [lat],[lng]) typed in. The rider still presses send: nothing goes out on
/// its own. The body goes in `query`: `queryParameters` would encode spaces
/// as `+`, which SMS apps show literally.
Uri locationSmsUri(
    String phone, double lat, double lng, String Function(String link) body) {
  final link = 'https://maps.google.com/?q=$lat,$lng';
  return Uri(
    scheme: 'sms',
    path: telUri(phone)?.path ?? phone.trim(),
    query: 'body=${Uri.encodeComponent(body(link))}',
  );
}

/// [Help] on Simple Home: call or text the rider's emergency contacts
/// (the same ones as Settings), or add the first one right here.
class SimpleHomeHelpSheet extends ConsumerWidget {
  const SimpleHomeHelpSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => const SimpleHomeHelpSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contacts = ref.watch(myEmergencyContactsProvider);
    final list = contacts.valueOrNull ?? const <EmergencyContactEntity>[];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.simpleHomeHelpTitle,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l10n.simpleHomeHelpBody),
            const SizedBox(height: 16),
            if (contacts.isLoading && !contacts.hasValue)
              const Center(child: CircularProgressIndicator())
            // Failed to load is not "no contacts": don't tell a rider who
            // has some to add one.
            else if (contacts.hasError && !contacts.hasValue) ...[
              Text(l10n.simpleHomeContactsFailed,
                  key: const Key('simple_home_contacts_failed')),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('simple_home_contacts_retry'),
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () => ref.invalidate(myEmergencyContactsProvider),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ] else if (list.isEmpty) ...[
              Text(l10n.simpleHomeNoContacts),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('simple_home_add_contact'),
                style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                // Settings' own add dialog, same repository; the sheet stays
                // open and shows Call once the contact is saved.
                onPressed: () => SettingsEmergencyContactsSection.showAddDialog(
                    context, ref),
                icon: const Icon(Icons.person_add_alt),
                label: Text(l10n.simpleHomeAddContact),
              ),
            ] else
              for (final c in list) _ContactRow(contact: c),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends ConsumerWidget {
  final EmergencyContactEntity contact;
  const _ContactRow({required this.contact});

  Future<void> _sendLocation(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final double lat, lng;
    try {
      final pos = await ref.refresh(currentPositionProvider.future);
      (lat, lng) = (pos.latitude, pos.longitude);
    } catch (e, st) {
      reportSilently(e, st, where: 'Simple help: location fix');
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.simpleHomeLocationFailed)));
      return;
    }
    var opened = false;
    try {
      opened = await launchUrl(
          locationSmsUri(contact.phone, lat, lng, l10n.simpleHomeLocationSms));
    } catch (e, st) {
      reportSilently(e, st, where: 'Simple help: open SMS');
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.simpleHomeSmsFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tel = telUri(contact.phone);
    const tall = Size(64, 48);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(contact.name, style: Theme.of(context).textTheme.titleMedium),
          Text(contact.phone),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (tel != null)
                FilledButton.icon(
                  key: Key('simple_home_call_${contact.id}'),
                  style: FilledButton.styleFrom(minimumSize: tall),
                  onPressed: () => PlaceLaunchActions.call(context, tel),
                  icon: const Icon(Icons.call),
                  label: Text(l10n.call),
                ),
              OutlinedButton.icon(
                key: Key('simple_home_send_location_${contact.id}'),
                style: OutlinedButton.styleFrom(minimumSize: tall),
                onPressed: () => _sendLocation(context, ref),
                icon: const Icon(Icons.share_location),
                label: Text(l10n.simpleHomeSendLocation),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
