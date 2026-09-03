import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/report_repository.dart';

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
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
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

  final List<String> _reasons = [
    'Spam or misleading',
    'Harassment or bullying',
    'Hate speech',
    'Inappropriate content',
    'Self-harm',
    'Other',
  ];

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
          const SnackBar(content: Text('Report submitted successfully. We will review it shortly.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e'), backgroundColor: AppColors.danger),
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
                'Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Why are you reporting this?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ..._reasons.map((reason) => RadioListTile<String>(
                title: Text(reason, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                value: reason,
                groupValue: _selectedReason,
                onChanged: (value) => setState(() => _selectedReason = value),
                fillColor: WidgetStatePropertyAll(AppColors.primary),
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
          const SizedBox(height: 16),
          TextField(
            controller: _detailsController,
            style: TextStyle(color: AppColors.textPrimary),
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Additional details (optional)',
              labelStyle: TextStyle(color: AppColors.textTertiary),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _selectedReason == null || _isSubmitting ? null : _submitReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
