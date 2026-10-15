import 'dart:ui';

/// Pure geometry for the photo cropper (`shared/screens/image_crop_screen.dart`).
///
/// All of it is separated from the widget deliberately. Crop maths is the part
/// that is easy to get subtly wrong — a handle that lets the frame escape the
/// photo, an aspect ratio that drifts a pixel per drag until it's visibly not
/// square, a mapping that crops the wrong region on a portrait photo — and all
/// of those are invisible in review and obvious to a user. None of it needs a
/// widget tree to test.
///
/// Two coordinate spaces are in play and must not be confused:
///
///  * **display space** — logical pixels inside the crop screen's viewport,
///    where the photo has been letterboxed to fit ([fitInside]). Everything
///    the user drags lives here.
///  * **source space** — the decoded image's own pixel grid, which is what
///    `package:image`'s `copyCrop` wants. [toSourceRect] is the one crossing.

/// The largest rect with [content]'s aspect ratio that fits inside [viewport],
/// centred — i.e. `BoxFit.contain` as a rect.
Rect fitInside(Size content, Size viewport) {
  if (content.width <= 0 || content.height <= 0) return Rect.zero;
  final scale = (viewport.width / content.width) < (viewport.height / content.height)
      ? viewport.width / content.width
      : viewport.height / content.height;
  final w = content.width * scale;
  final h = content.height * scale;
  return Rect.fromLTWH(
    (viewport.width - w) / 2,
    (viewport.height - h) / 2,
    w,
    h,
  );
}

/// The crop frame a photo opens with: the whole photo when unconstrained, or
/// the largest centred [aspectRatio] rect that fits inside it.
///
/// Opening on the *whole* photo rather than an arbitrary inset matters — "I
/// only want to nudge the edges in" is the common case, and starting from a
/// smaller box makes the rider drag four handles outward before they can begin.
Rect initialCropRect(Rect bounds, {double? aspectRatio}) {
  if (aspectRatio == null || aspectRatio <= 0) return bounds;

  var w = bounds.width;
  var h = w / aspectRatio;
  if (h > bounds.height) {
    h = bounds.height;
    w = h * aspectRatio;
  }
  return Rect.fromLTWH(
    bounds.left + (bounds.width - w) / 2,
    bounds.top + (bounds.height - h) / 2,
    w,
    h,
  );
}

/// Which part of the crop frame a drag grabbed.
enum CropHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,

  /// The interior — moves the whole frame without resizing it.
  move,
}

/// Hit-tests [point] against [rect]'s handles.
///
/// Corners win over edges (they overlap, and a corner drag is the more
/// specific intent), and [slop] is generous because this is a fingertip on a
/// thin line, not a mouse cursor. Returns null when the point is outside the
/// frame and its slop entirely.
CropHandle? handleAt(Rect rect, Offset point, {double slop = 28}) {
  final nearLeft = (point.dx - rect.left).abs() <= slop;
  final nearRight = (point.dx - rect.right).abs() <= slop;
  final nearTop = (point.dy - rect.top).abs() <= slop;
  final nearBottom = (point.dy - rect.bottom).abs() <= slop;

  final withinX = point.dx >= rect.left - slop && point.dx <= rect.right + slop;
  final withinY = point.dy >= rect.top - slop && point.dy <= rect.bottom + slop;
  if (!withinX || !withinY) return null;

  if (nearLeft && nearTop) return CropHandle.topLeft;
  if (nearRight && nearTop) return CropHandle.topRight;
  if (nearLeft && nearBottom) return CropHandle.bottomLeft;
  if (nearRight && nearBottom) return CropHandle.bottomRight;
  if (nearLeft) return CropHandle.left;
  if (nearRight) return CropHandle.right;
  if (nearTop) return CropHandle.top;
  if (nearBottom) return CropHandle.bottom;

  return rect.contains(point) ? CropHandle.move : null;
}

/// Applies a drag of [delta] on [handle] to [crop], keeping the result inside
/// [bounds], no smaller than [minSize] on either side, and — when
/// [aspectRatio] is set — exactly that ratio.
///
/// [CropHandle.move] translates without resizing and is clamped rather than
/// rejected: dragging the frame into the edge of the photo should slide along
/// it, not stop dead the moment one axis is blocked.
Rect applyHandleDrag({
  required Rect crop,
  required CropHandle handle,
  required Offset delta,
  required Rect bounds,
  double? aspectRatio,
  double minSize = 48,
}) {
  if (handle == CropHandle.move) {
    final dx = delta.dx.clamp(bounds.left - crop.left, bounds.right - crop.right);
    final dy = delta.dy.clamp(bounds.top - crop.top, bounds.bottom - crop.bottom);
    return crop.shift(Offset(dx, dy));
  }

  var left = crop.left;
  var top = crop.top;
  var right = crop.right;
  var bottom = crop.bottom;

  final movesLeft = handle == CropHandle.left ||
      handle == CropHandle.topLeft ||
      handle == CropHandle.bottomLeft;
  final movesRight = handle == CropHandle.right ||
      handle == CropHandle.topRight ||
      handle == CropHandle.bottomRight;
  final movesTop = handle == CropHandle.top ||
      handle == CropHandle.topLeft ||
      handle == CropHandle.topRight;
  final movesBottom = handle == CropHandle.bottom ||
      handle == CropHandle.bottomLeft ||
      handle == CropHandle.bottomRight;

  if (movesLeft) left = (left + delta.dx).clamp(bounds.left, right - minSize);
  if (movesRight) right = (right + delta.dx).clamp(left + minSize, bounds.right);
  if (movesTop) top = (top + delta.dy).clamp(bounds.top, bottom - minSize);
  if (movesBottom) bottom = (bottom + delta.dy).clamp(top + minSize, bounds.bottom);

  var result = Rect.fromLTRB(left, top, right, bottom);
  if (aspectRatio != null && aspectRatio > 0) {
    result = _enforceRatio(result, handle, bounds, aspectRatio, minSize);
  }
  return result;
}

/// Forces [rect] to [aspectRatio] by adjusting whichever side the drag isn't
/// pinning, then pulls it back inside [bounds] if that pushed it out.
///
/// The anchor is the corner/edge *opposite* the one being dragged, so the part
/// of the frame the rider isn't touching stays put — a top-left drag grows
/// from the bottom-right and vice versa. Getting this backwards makes the
/// frame appear to slide away from the finger.
Rect _enforceRatio(
  Rect rect,
  CropHandle handle,
  Rect bounds,
  double aspectRatio,
  double minSize,
) {
  final anchorRight = handle == CropHandle.left ||
      handle == CropHandle.topLeft ||
      handle == CropHandle.bottomLeft;
  final anchorBottom = handle == CropHandle.top ||
      handle == CropHandle.topLeft ||
      handle == CropHandle.topRight;

  // Horizontal drags drive width and derive height; vertical drags do the
  // reverse. Corners drive from width, which keeps a diagonal drag feeling
  // like one gesture rather than two fighting each other.
  final drivenByWidth = handle != CropHandle.top && handle != CropHandle.bottom;

  var w = rect.width;
  var h = rect.height;
  if (drivenByWidth) {
    h = w / aspectRatio;
  } else {
    w = h * aspectRatio;
  }

  // Shrink to fit the bounds before positioning, so a ratio that would push
  // the frame off the photo comes back as a smaller frame rather than a
  // clipped, wrong-ratio one.
  if (w > bounds.width) {
    w = bounds.width;
    h = w / aspectRatio;
  }
  if (h > bounds.height) {
    h = bounds.height;
    w = h * aspectRatio;
  }
  if (w < minSize) {
    w = minSize;
    h = w / aspectRatio;
  }
  if (h < minSize) {
    h = minSize;
    w = h * aspectRatio;
  }

  var left = anchorRight ? rect.right - w : rect.left;
  var top = anchorBottom ? rect.bottom - h : rect.top;

  left = left.clamp(bounds.left, bounds.right - w);
  top = top.clamp(bounds.top, bounds.bottom - h);

  return Rect.fromLTWH(left, top, w, h);
}

/// Re-fits [crop] to a newly chosen [aspectRatio], keeping it centred on where
/// it already is. Used when the rider taps a preset mid-edit — the frame
/// should change shape around what they were already looking at, not jump back
/// to the middle of the photo.
Rect retargetAspectRatio(Rect crop, Rect bounds, double? aspectRatio) {
  if (aspectRatio == null || aspectRatio <= 0) return crop;

  var w = crop.width;
  var h = w / aspectRatio;
  if (h > bounds.height) {
    h = bounds.height;
    w = h * aspectRatio;
  }
  if (w > bounds.width) {
    w = bounds.width;
    h = w / aspectRatio;
  }

  final centre = crop.center;
  final left = (centre.dx - w / 2).clamp(bounds.left, bounds.right - w);
  final top = (centre.dy - h / 2).clamp(bounds.top, bounds.bottom - h);
  return Rect.fromLTWH(left, top, w, h);
}

/// Maps a crop frame in display space to the source image's pixel grid.
///
/// [display] is where the photo was drawn ([fitInside]'s result) and
/// [sourceSize] is the decoded image's real dimensions. The result is clamped
/// to the image and guaranteed at least 1×1, because `copyCrop` with a zero or
/// out-of-range rect is a decode error rather than a small picture.
Rect toSourceRect(Rect crop, Rect display, Size sourceSize) {
  if (display.width <= 0 || display.height <= 0) return Rect.zero;

  final scaleX = sourceSize.width / display.width;
  final scaleY = sourceSize.height / display.height;

  final left = ((crop.left - display.left) * scaleX).clamp(0.0, sourceSize.width);
  final top = ((crop.top - display.top) * scaleY).clamp(0.0, sourceSize.height);
  final right = ((crop.right - display.left) * scaleX).clamp(0.0, sourceSize.width);
  final bottom = ((crop.bottom - display.top) * scaleY).clamp(0.0, sourceSize.height);

  return Rect.fromLTRB(
    left,
    top,
    right > left ? right : left + 1,
    bottom > top ? bottom : top + 1,
  );
}

/// [size] with its axes swapped for odd quarter-turns — the dimensions a
/// photo takes on after [quarterTurns] × 90° of rotation.
Size rotatedSize(Size size, int quarterTurns) {
  return quarterTurns.isEven
      ? size
      : Size(size.height, size.width);
}
