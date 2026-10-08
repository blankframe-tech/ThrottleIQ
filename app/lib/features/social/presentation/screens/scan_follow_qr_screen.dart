import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../domain/utilities/follow_link.dart';
import '../../domain/utilities/follow_link_outcome.dart';
import '../providers/follow_link_providers.dart';

/// "Scan QR": reads another rider's follow QR (see MyFollowQrScreen) and
/// follows them straight away through [FollowLinkController], then opens the
/// People tab. Own code, already-followed riders and non-ThrottleIQ codes get
/// a message and scanning carries on.
class ScanFollowQrScreen extends ConsumerStatefulWidget {
  const ScanFollowQrScreen({super.key});

  @override
  ConsumerState<ScanFollowQrScreen> createState() => _ScanFollowQrScreenState();
}

class _ScanFollowQrScreenState extends ConsumerState<ScanFollowQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    // normal, not noDuplicates: a failed follow must be retryable by
    // re-scanning the same code. _handling gates repeats instead.
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    setState(() => _handling = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final result = await ref
        .read(followLinkControllerProvider)
        .followUid(parseFollowLink(raw), l10n: l10n);
    if (!mounted) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(followLinkResultMessage(l10n, result))));
    if (result.outcome == FollowLinkOutcome.followed ||
        result.outcome == FollowLinkOutcome.alreadyFollowing) {
      router.go(kFollowLinkLandingRoute);
      return;
    }
    // Self / invalid / failed: keep scanning. A short pause stops the same
    // message firing again while the code is still in frame.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _handling = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(l10n.scanQrTitle),
        actions: [
          IconButton(
            tooltip: l10n.scanQrTorch,
            icon: Icon(Icons.flashlight_on_outlined,
                color: context.palette.textPrimary),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => _ScannerError(error: error),
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: context.palette.primary, width: 3),
                        borderRadius:
                            BorderRadius.circular(context.shape.radiusLg),
                      ),
                    ),
                  ),
                ),
                if (_handling)
                  ColoredBox(
                    color: context.palette.overlayDark,
                    child: Center(
                      child: CircularProgressIndicator(
                          color: context.palette.primary),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  l10n.scanQrHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: context.palette.textSecondary),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => context.pushReplacement('/profile/qr'),
                  icon: Icon(Icons.qr_code_2, color: context.palette.primary),
                  label: Text(l10n.myQrTitle,
                      style: TextStyle(color: context.palette.primary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: context.palette.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined,
                  size: 40, color: context.palette.textTertiary),
              const SizedBox(height: 12),
              Text(
                denied ? l10n.scanQrCameraDenied : l10n.scanQrCameraError,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.palette.textSecondary),
              ),
              if (denied) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: openAppSettings,
                  child: Text(l10n.openSettings),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
