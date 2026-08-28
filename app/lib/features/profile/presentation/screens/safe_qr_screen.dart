import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/medical_info_entity.dart';
import '../../domain/safe_qr_payload.dart';
import '../providers/emergency_contacts_provider.dart';
import '../providers/medical_info_provider.dart';

/// SafeQR — a scannable medical-info card for first responders, built and
/// read entirely on-device (`safe_qr_payload.dart`, `medical_info_provider
/// .dart`). No account, no scanning half, no backend: any phone camera reads
/// it.
class SafeQrScreen extends ConsumerStatefulWidget {
  const SafeQrScreen({super.key});

  @override
  ConsumerState<SafeQrScreen> createState() => _SafeQrScreenState();
}

class _SafeQrScreenState extends ConsumerState<SafeQrScreen> {
  late final TextEditingController _bloodGroupCtrl;
  late final TextEditingController _allergiesCtrl;
  late final TextEditingController _conditionsCtrl;
  late final TextEditingController _medicationsCtrl;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(medicalInfoProvider);
    _bloodGroupCtrl = TextEditingController(text: saved.bloodGroup);
    _allergiesCtrl = TextEditingController(text: saved.allergies);
    _conditionsCtrl = TextEditingController(text: saved.conditions);
    _medicationsCtrl = TextEditingController(text: saved.medications);
  }

  @override
  void dispose() {
    _bloodGroupCtrl.dispose();
    _allergiesCtrl.dispose();
    _conditionsCtrl.dispose();
    _medicationsCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    ref.read(medicalInfoProvider.notifier).save(
          ref.read(medicalInfoProvider).copyWith(
                bloodGroup: _bloodGroupCtrl.text.trim(),
                allergies: _allergiesCtrl.text.trim(),
                conditions: _conditionsCtrl.text.trim(),
                medications: _medicationsCtrl.text.trim(),
              ),
        );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.safeQrSavedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    // A live preview: typing into a field updates the QR code immediately,
    // not just after Save — the whole point is seeing what a scan would show.
    final medicalInfo = MedicalInfoEntity(
      bloodGroup: _bloodGroupCtrl.text,
      allergies: _allergiesCtrl.text,
      conditions: _conditionsCtrl.text,
      medications: _medicationsCtrl.text,
    );
    final contacts = ref.watch(myEmergencyContactsProvider).valueOrNull;
    final firstContact = (contacts != null && contacts.isNotEmpty)
        ? SafeQrEmergencyContact(
            name: contacts.first.name, phone: contacts.first.phone)
        : null;
    final riderName = user?.displayName ?? '';
    final hasContent = safeQrPayloadHasContent(
      riderName: riderName,
      medicalInfo: medicalInfo,
      emergencyContact: firstContact,
    );
    final payload = buildSafeQrPayload(
      riderName: riderName,
      medicalInfo: medicalInfo,
      emergencyContact: firstContact,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.safeQrTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.safeQrIntro,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: hasContent
                  ? QrImageView(
                      data: payload,
                      size: 200,
                      backgroundColor: Colors.white,
                    )
                  : SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(
                        child: Text(
                          l10n.safeQrEmptyStateHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: Colors.black45),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.safeQrMedicalInfoSection,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          TextField(
            controller: _bloodGroupCtrl,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: l10n.safeQrBloodGroupField,
              hintText: l10n.safeQrBloodGroupHint,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _allergiesCtrl,
            maxLines: 2,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(labelText: l10n.safeQrAllergiesField),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _conditionsCtrl,
            maxLines: 2,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(labelText: l10n.safeQrConditionsField),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _medicationsCtrl,
            maxLines: 2,
            style: TextStyle(color: AppColors.textPrimary),
            decoration:
                InputDecoration(labelText: l10n.safeQrMedicationsField),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text(
            firstContact != null
                ? l10n.safeQrContactIncludedNote(firstContact.name)
                : l10n.safeQrNoContactNote,
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _save,
              child: Text(l10n.safeQrSaveAction),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.safeQrLocalOnlyDisclaimer,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
