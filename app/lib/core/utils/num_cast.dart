/// Safe numeric reads for data that crossed a JSON/Firestore boundary.
///
/// `value as double` throws when the value arrived as an `int`, which is
/// exactly what Firestore hands back for a whole number written by anything
/// other than this app: a JS client, the console, a Cloud Function,
/// `live-viewer.html`. `24` and `24.0` are the same coordinate; only one of
/// them survives a raw cast. Read Firestore numbers through these instead.
library;

/// [v] as a `double`, accepting any `num`. Throws if [v] is null or not a
/// number, same as the raw cast would for those.
double asDouble(Object? v) => (v as num).toDouble();

/// Nullable [asDouble]: null stays null.
double? asDoubleOrNull(Object? v) => (v as num?)?.toDouble();
