import 'package:flutter/material.dart';

import '../../core/theme/app_theme_context.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/bug_report_service.dart';

/// A bottom sheet that lets the rider describe a problem and send a bug report.
///
/// Shows a text field and a "Send Report" button. On send, the report is saved
/// to the device's Documents folder and the native share sheet opens so the
/// rider can email or message it to the dev team.
///
/// Usage:
/// ```dart
/// BugReportSheet.show(context);
/// ```
class BugReportSheet extends StatefulWidget {
  const BugReportSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const BugReportSheet._(),
    );
  }

  @override
  State<BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<BugReportSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _feedback;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _feedback = 'Please describe the problem before sending.');
      return;
    }
    setState(() {
      _sending = true;
      _feedback = null;
    });
    try {
      await BugReportService.instance.submit(text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _feedback = 'Could not send the report. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
        left: AppDimensions.paddingMd,
        right: AppDimensions.paddingMd,
        top: AppDimensions.paddingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.bug_report_outlined, color: context.palette.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Send Bug Report',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: context.palette.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                color: context.palette.textSecondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Describe what happened. Your UID and app version are included automatically.',
            style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 5,
            style: TextStyle(color: context.palette.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. "Messages wouldn\'t send — I got an error about permissions."',
              hintStyle: TextStyle(color: context.palette.textTertiary, fontSize: 13),
              filled: true,
              fillColor: context.palette.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.shape.radiusMd),
                borderSide: BorderSide(color: context.palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.shape.radiusMd),
                borderSide: BorderSide(color: context.palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.shape.radiusMd),
                borderSide: BorderSide(color: context.palette.primary),
              ),
            ),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 8),
            Text(
              _feedback!,
              style: TextStyle(fontSize: 12, color: context.palette.danger),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_outlined, size: 18),
            label: Text(_sending ? 'Sending…' : 'Send Report'),
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.primary,
              minimumSize: const Size(0, 48),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
