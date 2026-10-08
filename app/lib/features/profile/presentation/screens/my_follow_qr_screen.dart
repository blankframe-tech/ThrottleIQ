import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../social/presentation/providers/follow_link_providers.dart';
import '../providers/profile_providers.dart';

/// "My QR code": the signed-in rider's follow link as a QR. Another rider
/// scans it — with ThrottleIQ's own scanner or their phone camera — and
/// follows them.
///
/// The link is read from the device ([myFollowLinkProvider]); it is built and
/// saved only the first time, and the PNG used for Share / Save image is
/// rendered once into app documents and reused after that.
class MyFollowQrScreen extends ConsumerStatefulWidget {
  const MyFollowQrScreen({super.key});

  @override
  ConsumerState<MyFollowQrScreen> createState() => _MyFollowQrScreenState();
}

class _MyFollowQrScreenState extends ConsumerState<MyFollowQrScreen> {
  final GlobalKey _shareButtonKey = GlobalKey();
  bool _busy = false;

  /// The saved QR image for [link], rendering it the first time only.
  Future<File> _qrImage(String uid, String link) async {
    final foreground = context.palette.ink;
    final background = context.palette.onInk;
    final store = ref.read(followLinkStoreProvider);
    final file = await store.myQrImageFile(uid);
    if (await file.exists() && await file.length() > 0) return file;
    final bytes = await renderFollowQrPng(
      data: link,
      foreground: foreground,
      background: background,
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _run(Future<void> Function(String uid, String link) action) async {
    final uid = ref.read(currentUserProvider)?.uid;
    final link = ref.read(myFollowLinkProvider).valueOrNull;
    if (_busy || uid == null || link == null) return;
    setState(() => _busy = true);
    try {
      await action(uid, link);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() => _run((uid, link) async {
        final l10n = context.l10n;
        try {
          final file = await _qrImage(uid, link);
          if (!mounted) return;
          // Anchors the iPad share popover — see safe_qr_screen.dart.
          Rect? origin;
          final box =
              _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            origin = box.localToGlobal(Offset.zero) & box.size;
          }
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'image/png')],
            text: l10n.myQrShareText(link),
            subject: l10n.myQrTitle,
            sharePositionOrigin: origin,
          );
        } catch (_) {
          _snack(l10n.myQrImageFailed);
        }
      });

  Future<void> _save() => _run((uid, link) async {
        final l10n = context.l10n;
        try {
          final file = await _qrImage(uid, link);
          if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
            _snack(l10n.myQrSaveNoAccess);
            return;
          }
          await Gal.putImage(file.path);
          _snack(l10n.myQrSaved);
        } catch (_) {
          _snack(l10n.myQrImageFailed);
        }
      });

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final linkAsync = ref.watch(myFollowLinkProvider);
    final me = ref.watch(myProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(l10n.myQrTitle)),
      body: linkAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: context.palette.primary)),
        error: (_, __) => Center(
          child: Text(l10n.myQrImageFailed,
              style: TextStyle(color: context.palette.textSecondary)),
        ),
        data: (link) {
          if (link == null) {
            return Center(
              child: Text(l10n.signViewProfile,
                  style: TextStyle(color: context.palette.textSecondary)),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                l10n.myQrIntro,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    // ink-on-onInk is near-black on near-white in every color
                    // mode and brightness — what a scanner needs.
                    color: context.palette.onInk,
                    borderRadius: BorderRadius.circular(context.shape.radiusLg),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(
                        data: link,
                        size: 220,
                        backgroundColor: context.palette.onInk,
                        eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: context.palette.ink),
                        dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: context.palette.ink),
                      ),
                      if (me != null) ...[
                        const SizedBox(height: 12),
                        Text(me.bestName,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: context.palette.ink)),
                        if (me.username != null)
                          Text('@${me.username}',
                              style: TextStyle(
                                  fontSize: 13, color: context.palette.ink)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                link,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: _shareButtonKey,
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: Text(l10n.myQrShareAction),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(l10n.myQrSaveAction),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => context.pushReplacement('/profile/scan'),
                icon: Icon(Icons.qr_code_scanner, color: context.palette.primary),
                label: Text(l10n.scanQrAction,
                    style: TextStyle(color: context.palette.primary)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Renders [data] as a square QR PNG with a quiet-zone margin — the image
/// Share / Save image hand out. Colors are passed in (theme tokens) so this
/// stays free of `BuildContext`.
Future<List<int>> renderFollowQrPng({
  required String data,
  required Color foreground,
  required Color background,
  double size = 1024,
}) async {
  final painter = QrPainter(
    data: data,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    gapless: true,
    eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: foreground),
    dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square, color: foreground),
  );
  final margin = size * 0.08;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(Rect.fromLTWH(0, 0, size, size), Paint()..color = background)
    ..translate(margin, margin);
  painter.paint(canvas, Size.square(size - 2 * margin));
  final image =
      await recorder.endRecording().toImage(size.round(), size.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) throw StateError('PNG encode failed');
  return bytes.buffer.asUint8List();
}
