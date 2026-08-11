import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/utils/crop_geometry.dart';
import '../../core/utils/image_crop_io.dart';
import '../widgets/editorial.dart';

/// A themed, in-app photo cropper.
///
/// Deliberately built rather than pulled in as `image_cropper`: that plugin's
/// screen is native chrome (UCrop / TOCropViewController), which looks correct
/// on exactly zero of this app's nine skins and would be the one screen that
/// ignores the palette a rider picked. It also wants an Android manifest entry
/// and a pod. This uses `package:image`, already a dependency for
/// `ImageCompressionUtils`, and the crop maths lives in
/// `core/utils/crop_geometry.dart` where it is unit-tested.
///
/// **Interaction model: the photo is fixed and the frame moves.** The
/// alternative — a fixed frame with a pan/zoomable photo underneath — is what
/// Instagram does, and it makes an unconstrained "free" crop awkward to
/// express. Here the photo is letterboxed to fit, and the frame is dragged and
/// resized over it, which makes Free the natural default and turns the aspect
/// presets into a constraint on the frame rather than a different mode.
///
/// Push it with [ImageCropScreen.open] and it returns the path of a **new**
/// JPEG file, or null if the rider backed out. The original is never modified.
class ImageCropScreen extends StatefulWidget {
  const ImageCropScreen({
    super.key,
    required this.sourcePath,
    this.title = 'Crop photo',
    this.filePrefix = 'photo',
  });

  final String sourcePath;
  final String title;

  /// Filename stem for the written crop — just makes the app's documents
  /// directory readable when someone goes looking (`bike_photo_…jpg`).
  final String filePrefix;

  /// Pushes the cropper for [sourcePath] and resolves to the cropped file's
  /// path, or null if the rider cancelled.
  static Future<String?> open(
    BuildContext context, {
    required String sourcePath,
    String title = 'Crop photo',
    String filePrefix = 'photo',
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageCropScreen(
          sourcePath: sourcePath,
          title: title,
          filePrefix: filePrefix,
        ),
      ),
    );
  }

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

/// The aspect presets. `null` means unconstrained.
const _presets = <({String label, double? ratio})>[
  (label: 'Free', ratio: null),
  (label: '1:1', ratio: 1),
  (label: '4:3', ratio: 4 / 3),
  (label: '16:9', ratio: 16 / 9),
];

class _ImageCropScreenState extends State<ImageCropScreen> {
  /// Decoded once for display. The crop itself re-reads and re-decodes the
  /// file at full resolution — cropping the preview would hand back an image
  /// no larger than the phone's screen.
  ui.Image? _preview;
  String? _error;
  bool _saving = false;

  int _quarterTurns = 0;
  double? _ratio;

  /// Where the photo is drawn, and the frame over it — both in display space.
  /// Null until the first layout, since both depend on the viewport size.
  Rect? _display;
  Rect? _crop;

  CropHandle? _dragging;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.sourcePath).readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      if (!mounted) return;
      setState(() => _preview = decoded);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open that photo.');
    }
  }

  @override
  void dispose() {
    _preview?.dispose();
    super.dispose();
  }

  /// The photo's on-screen size, accounting for rotation.
  Size get _sourceSize {
    final p = _preview!;
    return rotatedSize(
      Size(p.width.toDouble(), p.height.toDouble()),
      _quarterTurns,
    );
  }

  void _layoutFor(Size viewport) {
    final display = fitInside(_sourceSize, viewport);
    if (_display == display && _crop != null) return;
    _display = display;
    _crop = initialCropRect(display, aspectRatio: _ratio);
  }

  void _setRatio(double? ratio) {
    setState(() {
      _ratio = ratio;
      final display = _display;
      final crop = _crop;
      if (display != null && crop != null) {
        _crop = ratio == null ? crop : retargetAspectRatio(crop, display, ratio);
      }
    });
  }

  void _rotate() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      // The photo's display rect changes shape, so the old frame is
      // meaningless — recompute both on the next layout pass.
      _display = null;
      _crop = null;
    });
  }

  Future<void> _save() async {
    final crop = _crop;
    final display = _display;
    final preview = _preview;
    if (crop == null || display == null || preview == null || _saving) return;

    setState(() => _saving = true);
    try {
      final path = await writeCroppedImage(
        sourcePath: widget.sourcePath,
        cropInDisplaySpace: crop,
        displayRect: display,
        quarterTurns: _quarterTurns,
        filePrefix: widget.filePrefix,
      );
      if (!mounted) return;
      Navigator.of(context).pop(path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the cropped photo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: (_preview == null || _saving) ? null : _save,
            child: _saving
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : const Text('Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildCanvas()),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
              child: Text(_error!,
                  style: TextStyle(color: AppColors.danger, fontSize: 13),
                  textAlign: TextAlign.center),
            ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    if (_preview == null) {
      return Center(
        child: _error != null
            ? Icon(Icons.broken_image_outlined, size: 48, color: AppColors.textTertiary)
            : CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        _layoutFor(viewport);
        final display = _display!;
        final crop = _crop!;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _dragging = handleAt(crop, details.localPosition);
          },
          onPanUpdate: (details) {
            final handle = _dragging;
            if (handle == null) return;
            setState(() {
              _crop = applyHandleDrag(
                crop: _crop!,
                handle: handle,
                delta: details.delta,
                bounds: display,
                aspectRatio: _ratio,
              );
            });
          },
          onPanEnd: (_) => _dragging = null,
          onPanCancel: () => _dragging = null,
          child: CustomPaint(
            size: viewport,
            painter: _CropPainter(
              image: _preview!,
              quarterTurns: _quarterTurns,
              display: display,
              crop: crop,
              scrim: AppColors.overlayDark,
              frame: AppColors.primary,
              grid: AppColors.onInk.withValues(alpha: 0.35),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingMd,
        AppDimensions.paddingMd,
        AppDimensions.paddingMd,
        MediaQuery.of(context).padding.bottom + AppDimensions.paddingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presets)
                _RatioChip(
                  label: preset.label,
                  selected: _ratio == preset.ratio,
                  onTap: _preview == null ? null : () => _setRatio(preset.ratio),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _preview == null || _saving ? null : _rotate,
            icon: const Icon(Icons.rotate_90_degrees_ccw_outlined, size: 18),
            label: const Text('Rotate'),
          ),
        ],
      ),
    );
  }
}

class _RatioChip extends StatelessWidget {
  const _RatioChip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: display(
            13,
            letterSpacing: 0,
            color: selected
                ? (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.surface
                    : Colors.white)
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Draws the photo, dims everything outside the frame, and paints the frame
/// with corner grips and a rule-of-thirds grid.
class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.quarterTurns,
    required this.display,
    required this.crop,
    required this.scrim,
    required this.frame,
    required this.grid,
  });

  final ui.Image image;
  final int quarterTurns;
  final Rect display;
  final Rect crop;
  final Color scrim;
  final Color frame;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    _paintImage(canvas);

    // Dim everything outside the frame. Even-odd on a path holding the whole
    // canvas plus the crop rect punches the frame out in one fill, rather than
    // painting four rects around it and fighting their seams.
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(crop);
    canvas.drawPath(mask, Paint()..color = scrim);

    // Rule-of-thirds guides.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 0.75;
    for (var i = 1; i < 3; i++) {
      final dx = crop.left + crop.width * i / 3;
      final dy = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(dx, crop.top), Offset(dx, crop.bottom), gridPaint);
      canvas.drawLine(Offset(crop.left, dy), Offset(crop.right, dy), gridPaint);
    }

    canvas.drawRect(
      crop,
      Paint()
        ..color = frame
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Corner grips — the affordance that says the frame is draggable at all.
    final grip = Paint()
      ..color = frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    const len = 22.0;
    void corner(Offset at, double dx, double dy) {
      canvas.drawLine(at, at.translate(len * dx, 0), grip);
      canvas.drawLine(at, at.translate(0, len * dy), grip);
    }

    corner(crop.topLeft, 1, 1);
    corner(crop.topRight, -1, 1);
    corner(crop.bottomLeft, 1, -1);
    corner(crop.bottomRight, -1, -1);
  }

  void _paintImage(Canvas canvas) {
    canvas.save();
    if (quarterTurns % 4 != 0) {
      // Rotate about the display rect's centre so the photo lands inside the
      // same box the frame is being clamped to.
      canvas.translate(display.center.dx, display.center.dy);
      canvas.rotate(quarterTurns * 3.1415926535897932 / 2);
      canvas.translate(-display.center.dx, -display.center.dy);
    }

    // After an odd rotation the drawn rect is the display rect with its axes
    // swapped, kept concentric — which is exactly what rotatedSize accounted
    // for when the display rect was computed.
    final target = quarterTurns.isEven
        ? display
        : Rect.fromCenter(
            center: display.center,
            width: display.height,
            height: display.width,
          );

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      target,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image ||
      old.quarterTurns != quarterTurns ||
      old.display != display ||
      old.crop != crop ||
      old.frame != frame;
}
