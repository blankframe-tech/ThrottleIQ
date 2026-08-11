import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/crop_geometry.dart';

/// The photo cropper's maths.
///
/// Everything here is the class of bug that survives review and is obvious to
/// a user the moment they touch it: a frame that escapes the photo, an aspect
/// preset that drifts off-ratio as you drag, or a crop that cuts the wrong
/// region because the letterbox offset wasn't subtracted.
void main() {
  group('fitInside', () {
    test('letterboxes content wider than the viewport', () {
      // 2:1 content in a square viewport → full width, centred vertically.
      final r = fitInside(const Size(200, 100), const Size(100, 100));
      expect(r, const Rect.fromLTWH(0, 25, 100, 50));
    });

    test('pillarboxes content taller than the viewport', () {
      final r = fitInside(const Size(100, 200), const Size(100, 100));
      expect(r, const Rect.fromLTWH(25, 0, 50, 100));
    });

    test('fills a viewport of the same aspect ratio exactly', () {
      final r = fitInside(const Size(400, 200), const Size(200, 100));
      expect(r, const Rect.fromLTWH(0, 0, 200, 100));
    });

    test('a degenerate source is Rect.zero, not a divide-by-zero', () {
      expect(fitInside(const Size(0, 0), const Size(100, 100)), Rect.zero);
    });
  });

  group('initialCropRect', () {
    const bounds = Rect.fromLTWH(10, 20, 200, 100);

    test('unconstrained opens on the whole photo', () {
      // Opening smaller would make "nudge the edges in" — the common case —
      // start with four outward drags.
      expect(initialCropRect(bounds), bounds);
    });

    test('a square in a wide photo is limited by height and centred', () {
      final r = initialCropRect(bounds, aspectRatio: 1);
      expect(r.width, 100);
      expect(r.height, 100);
      expect(r.center.dx, bounds.center.dx);
    });

    test('a wide ratio in a tall photo is limited by width', () {
      final r = initialCropRect(const Rect.fromLTWH(0, 0, 100, 400),
          aspectRatio: 16 / 9);
      expect(r.width, 100);
      expect(r.height, closeTo(56.25, 0.01));
    });
  });

  group('handleAt', () {
    const rect = Rect.fromLTWH(100, 100, 200, 200);

    test('corners win over the edges they overlap', () {
      expect(handleAt(rect, const Offset(100, 100)), CropHandle.topLeft);
      expect(handleAt(rect, const Offset(300, 100)), CropHandle.topRight);
      expect(handleAt(rect, const Offset(100, 300)), CropHandle.bottomLeft);
      expect(handleAt(rect, const Offset(300, 300)), CropHandle.bottomRight);
    });

    test('edges away from the corners', () {
      expect(handleAt(rect, const Offset(100, 200)), CropHandle.left);
      expect(handleAt(rect, const Offset(300, 200)), CropHandle.right);
      expect(handleAt(rect, const Offset(200, 100)), CropHandle.top);
      expect(handleAt(rect, const Offset(200, 300)), CropHandle.bottom);
    });

    test('the interior moves the whole frame', () {
      expect(handleAt(rect, const Offset(200, 200)), CropHandle.move);
    });

    test('well outside the frame grabs nothing', () {
      expect(handleAt(rect, const Offset(20, 20)), isNull);
      expect(handleAt(rect, const Offset(400, 400)), isNull);
    });

    test('slop catches a near miss, since this is a fingertip on a line', () {
      expect(handleAt(rect, const Offset(96, 200)), CropHandle.left);
    });
  });

  group('applyHandleDrag', () {
    const bounds = Rect.fromLTWH(0, 0, 400, 400);
    const crop = Rect.fromLTWH(100, 100, 200, 200);

    test('move translates without resizing', () {
      final r = applyHandleDrag(
        crop: crop,
        handle: CropHandle.move,
        delta: const Offset(20, -30),
        bounds: bounds,
      );
      expect(r, const Rect.fromLTWH(120, 70, 200, 200));
    });

    test('move slides along an edge instead of stopping dead', () {
      // Dragging hard up-left: x is free to move to the wall, y likewise —
      // blocking one axis must not freeze the other.
      final r = applyHandleDrag(
        crop: crop,
        handle: CropHandle.move,
        delta: const Offset(-500, -20),
        bounds: bounds,
      );
      expect(r.left, 0);
      expect(r.top, 80);
      expect(r.size, crop.size);
    });

    test('a side handle cannot be dragged past its opposite', () {
      final r = applyHandleDrag(
        crop: crop,
        handle: CropHandle.left,
        delta: const Offset(500, 0),
        bounds: bounds,
      );
      expect(r.width, greaterThanOrEqualTo(48));
      expect(r.left, lessThan(r.right));
    });

    test('the frame cannot escape the photo', () {
      final r = applyHandleDrag(
        crop: crop,
        handle: CropHandle.topLeft,
        delta: const Offset(-999, -999),
        bounds: bounds,
      );
      expect(bounds.contains(r.topLeft), isTrue);
      expect(r.left, greaterThanOrEqualTo(bounds.left));
      expect(r.top, greaterThanOrEqualTo(bounds.top));
    });

    test('an aspect ratio survives a corner drag', () {
      final r = applyHandleDrag(
        crop: crop,
        handle: CropHandle.bottomRight,
        delta: const Offset(40, 5), // deliberately off-ratio
        bounds: bounds,
        aspectRatio: 1,
      );
      expect(r.width, closeTo(r.height, 0.001));
    });

    test('a ratio drag anchors the corner the finger is not on', () {
      // Dragging bottom-right must leave top-left where it was; getting this
      // backwards makes the frame slide away from the finger.
      final r = applyHandleDrag(
        crop: crop,
        handle: CropHandle.bottomRight,
        delta: const Offset(40, 40),
        bounds: bounds,
        aspectRatio: 1,
      );
      expect(r.topLeft, crop.topLeft);
    });

    test('dragging top-left anchors bottom-right', () {
      final r = applyHandleDrag(
        crop: crop,
        handle: CropHandle.topLeft,
        delta: const Offset(-40, -40),
        bounds: bounds,
        aspectRatio: 1,
      );
      expect(r.bottomRight.dx, closeTo(crop.bottomRight.dx, 0.001));
      expect(r.bottomRight.dy, closeTo(crop.bottomRight.dy, 0.001));
    });

    test('a ratio that would overflow shrinks the frame rather than clipping it',
        () {
      // 16:9 forced inside a narrow-but-tall photo: the result must still be
      // exactly 16:9 AND still inside the bounds.
      const tall = Rect.fromLTWH(0, 0, 100, 400);
      final r = applyHandleDrag(
        crop: const Rect.fromLTWH(0, 0, 100, 100),
        handle: CropHandle.bottomRight,
        delta: const Offset(999, 999),
        bounds: tall,
        aspectRatio: 16 / 9,
      );
      expect(r.width / r.height, closeTo(16 / 9, 0.001));
      expect(r.width, lessThanOrEqualTo(tall.width + 0.001));
      expect(r.height, lessThanOrEqualTo(tall.height + 0.001));
    });
  });

  group('retargetAspectRatio', () {
    const bounds = Rect.fromLTWH(0, 0, 400, 400);

    test('keeps the frame where the rider was already looking', () {
      const crop = Rect.fromLTWH(50, 50, 120, 60);
      final r = retargetAspectRatio(crop, bounds, 1);
      expect(r.center.dx, closeTo(crop.center.dx, 0.001));
      expect(r.center.dy, closeTo(crop.center.dy, 0.001));
      expect(r.width, closeTo(r.height, 0.001));
    });

    test('null leaves the frame alone', () {
      const crop = Rect.fromLTWH(10, 10, 33, 77);
      expect(retargetAspectRatio(crop, bounds, null), crop);
    });

    test('pulls back inside the photo rather than overhanging it', () {
      const crop = Rect.fromLTWH(380, 380, 20, 20);
      final r = retargetAspectRatio(crop, bounds, 16 / 9);
      expect(r.right, lessThanOrEqualTo(bounds.right + 0.001));
      expect(r.bottom, lessThanOrEqualTo(bounds.bottom + 0.001));
    });
  });

  group('toSourceRect', () {
    test('scales a display crop up to the source pixel grid', () {
      // Photo drawn at 200×100 for a 400×200 source: everything doubles.
      const display = Rect.fromLTWH(0, 0, 200, 100);
      final r = toSourceRect(
          const Rect.fromLTWH(50, 25, 100, 50), display, const Size(400, 200));
      expect(r, const Rect.fromLTRB(100, 50, 300, 150));
    });

    test('subtracts the letterbox offset', () {
      // This is the bug the test exists for: forget display.left/top and the
      // crop lands somewhere else entirely on a letterboxed photo.
      const display = Rect.fromLTWH(20, 40, 200, 100);
      final r = toSourceRect(
          const Rect.fromLTWH(20, 40, 100, 50), display, const Size(400, 200));
      expect(r.left, 0);
      expect(r.top, 0);
      expect(r.width, 200);
      expect(r.height, 100);
    });

    test('clamps a frame that reaches past the photo', () {
      const display = Rect.fromLTWH(0, 0, 100, 100);
      final r = toSourceRect(
          const Rect.fromLTWH(-50, -50, 500, 500), display, const Size(100, 100));
      expect(r, const Rect.fromLTRB(0, 0, 100, 100));
    });

    test('never returns a zero-area rect', () {
      // copyCrop with a zero width/height is a decode error, not a tiny image.
      const display = Rect.fromLTWH(0, 0, 100, 100);
      final r = toSourceRect(
          const Rect.fromLTWH(10, 10, 0, 0), display, const Size(100, 100));
      expect(r.width, greaterThan(0));
      expect(r.height, greaterThan(0));
    });

    test('a degenerate display rect is Rect.zero, not a divide-by-zero', () {
      expect(toSourceRect(const Rect.fromLTWH(0, 0, 10, 10), Rect.zero,
          const Size(100, 100)),
          Rect.zero);
    });
  });

  group('rotatedSize', () {
    test('swaps axes on odd quarter turns only', () {
      const s = Size(400, 300);
      expect(rotatedSize(s, 0), s);
      expect(rotatedSize(s, 1), const Size(300, 400));
      expect(rotatedSize(s, 2), s);
      expect(rotatedSize(s, 3), const Size(300, 400));
    });
  });
}
