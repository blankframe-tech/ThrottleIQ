# Indriyo: random ideas

## Prompted object detection on the mirror feed (idea from @Sethnuzum, 2026-10-15)

Source: a post where Jev (TypeSafe AI's hosted model) is called 4 times a second with 5 lists of labels
to find objects in a webcam frame. It draws boxes with confidence and lists what is in view.

**Fit for Indriyo**
- `MjpegStreamService` already emits JPEG frames. Sample about 4 per second.
- `IndriyoVehicleDetection` already holds class, box, zone, distance and TTC. `IndriyoNotifier.updateThreatState` exists but has no callers: that is the missing piece.
- Blind-spot zone from the box's horizontal position. TTC from how fast the box grows between frames.
- Labels for riding: car, bus, truck, motorcycle, bicycle, person (rickshaw is not in COCO, so it needs a custom class).

**Why not Jev or Kev**
- Jev is hosted only. Cloud means cost per frame, latency, and no coverage on some rides. Bad for collision warnings.
- Kev (`labs_external/kev`) is open weight but text-only (Qwen-based, documents and typed questions). It runs on CUDA and MLX only, with no mobile runtime, and a language model cannot do 4 Hz on a phone.
- PixelJev ([arXiv:2609.29283](https://arxiv.org/abs/2609.29283)) is a 2B to 4B image-choice model. The abstract does not say weights are released, and it has no boxes and no phone numbers. Watch it, do not plan on it.

**Plan: on-device detector**
1. TFLite (Core ML on iPhone) small detector, COCO-trained, run at 2 to 4 Hz.
2. Map boxes to `IndriyoVehicleDetection`, feed `updateThreatState`.
3. Keep simulation mode as the fallback. Add tests for the box-to-threat mapping. Run `scripts/check.sh`.

**Risks and open questions**
- Licence: Ultralytics YOLO is AGPL. Prefer an Apache-licensed model for a shipped app.
- Heat: the phone runs GPS, the stream and the detector in the sun. Drop the rate when the phone gets hot.
- Not measured: real frame rate and thermals on a device.
- Tooltip "Toggle Indriyo ADAS Mirror" is hardcoded English, not l10n.
