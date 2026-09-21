import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/report_repository.dart';
import '../../../../core/i18n/l10n_context.dart';

class ReportBottomSheet extends ConsumerStatefulWidget {
  final String reportedId;
  final String contentType;
  final String contentId;

  const ReportBottomSheet({
    super.key,
    required this.reportedId,
    required this.contentType,
    required this.contentId,
  });

  static Future<void> show(
    BuildContext context, {
    required String reportedId,
    required String contentType,
    required String contentId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.shape.radiusLg)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ReportBottomSheet(
          reportedId: reportedId,
          contentType: contentType,
          contentId: contentId,
        ),
      ),
    );
  }

  @override
  ConsumerState<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends ConsumerState<ReportBottomSheet> {
  String? _selectedReason;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  /// The reason strings are what is stored on the report and read by
  /// moderators, so they stay English whatever the reporter's language; only
  /// what the reporter sees is localized (see [_reasonLabel]).
  static const List<String> _reasons = [
    'Spam or misleading',
    'Harassment or bullying',
    'Hate speech',
    'Inappropriate content',
    'Self-harm',
    'Other',
  ];

  String _reasonLabel(String reason) => switch (reason) {
        'Spam or misleading' => context.l10n.spamMisleading,
        'Harassment or bullying' => context.l10n.harassmentBullying,
        'Hate speech' => context.l10n.hateSpeech,
        'Inappropriate content' => context.l10n.inappropriateContent,
        'Self-harm' => context.l10n.selfHarm,
        _ => context.l10n.otherReason,
      };

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;
    
    final myUid = ref.read(currentUserProvider)?.uid;
    if (myUid == null) return;

    setState(() => _isSubmitting = true);

    try {
      await ReportRepository().submitReport(
        reporterId: myUid,
        reportedId: widget.reportedId,
        contentType: widget.contentType,
        contentId: widget.contentId,
        reason: _selectedReason!,
        additionalDetails: _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.reportSubmittedSuccessfullyWe)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failedSubmitReport(e)), backgroundColor: context.palette.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.report,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
              IconButton(
                tooltip: context.l10n.close,
                icon: Icon(Icons.close, color: context.palette.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.whyReportingThis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _selectedReason,
            onChanged: (value) => setState(() => _selectedReason = value),
            child: Column(
              children: [
                for (final reason in _reasons)
                  RadioListTile<String>(
                    title: Text(_reasonLabel(reason), style: TextStyle(color: context.palette.textPrimary, fontSize: 14)),
                    value: reason,
                    fillColor: WidgetStatePropertyAll(context.palette.primary),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _detailsController,
            style: TextStyle(color: context.palette.textPrimary),
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.l10n.additionalDetailsOptional,
              labelStyle: TextStyle(color: context.palette.textTertiary),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: context.palette.border),
                borderRadius: BorderRadius.circular(context.shape.radiusMd),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: context.palette.primary),
                borderRadius: BorderRadius.circular(context.shape.radiusMd),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _selectedReason == null || _isSubmitting ? null : _submitReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.palette.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.shape.radiusMd),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(context.l10n.submitReport, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
