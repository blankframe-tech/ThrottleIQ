import 'dart:math' as math;

/// Casual, time-aware greeting lines for the record screen.
///
/// Deliberately pure: the clock and the randomness are both injected, so the
/// whole module is testable without a `FakeAsync` or a global seed. Callers
/// pass the `DateTime` they want a greeting for and (in tests) a seeded
/// [math.Random] to make the pick reproducible.
///
/// Variants use a `{name}` placeholder rather than string concatenation at
/// every call site, so a variant can put the name wherever it reads best
/// ("Up early, {name}?") instead of always being prefixed. When no usable
/// name is available the placeholder falls back to [greetingNameFallback] —
/// it is never left in the output and never renders a dangling comma or the
/// literal "null".

/// The token variants use to mark where the rider's name goes.
const String greetingNamePlaceholder = '{name}';

/// Stand-in used when the rider has no usable display name. Lower-case
/// because every variant that uses `{name}` places it mid-sentence.
const String greetingNameFallback = 'rider';

/// Time-of-day buckets. Boundaries are inclusive of the start hour and run
/// to the end of the last hour in the range (e.g. [evening] is 17:00–20:59).
enum GreetingBucket {
  /// 00:00–04:59
  lateNight,

  /// 05:00–07:59
  earlyMorning,

  /// 08:00–11:59
  morning,

  /// 12:00–16:59
  afternoon,

  /// 17:00–20:59
  evening,

  /// 21:00–23:59
  night,
}

const List<String> _lateNight = [
  'Late night runs, huh?',
  'The roads are yours at this hour.',
  "Can't sleep? Ride it off.",
  'Empty streets, {name}.',
  'Nobody out there but you.',
];

const List<String> _earlyMorning = [
  'Beat the traffic.',
  'Cold start, clear roads.',
  'Sunrise miles hit different.',
  'Up early, {name}?',
  'First one out.',
];

const List<String> _morning = [
  'Morning, {name}.',
  'Ready when you are.',
  'Coffee first, then corners.',
  'Fresh tank, fresh day.',
  'Where to, {name}?',
];

const List<String> _afternoon = [
  'Afternoon, {name}.',
  'Good day for it.',
  "Sun's out. So are the roads.",
  'Long way home, {name}?',
  'Perfect time to slip away.',
];

const List<String> _evening = [
  'Evening, {name}.',
  'Golden hour. Go.',
  'Sunset run, {name}?',
  'Clock out. Gear up.',
  'Best light of the day.',
];

const List<String> _night = [
  'Night rider.',
  'One more before bed?',
  'Quiet roads, {name}.',
  'Cool air, empty lanes.',
  'Headlights on, {name}.',
];

/// Which bucket [now]'s hour-of-day falls into.
GreetingBucket greetingBucketFor(DateTime now) {
  final h = now.hour;
  if (h < 5) return GreetingBucket.lateNight;
  if (h < 8) return GreetingBucket.earlyMorning;
  if (h < 12) return GreetingBucket.morning;
  if (h < 17) return GreetingBucket.afternoon;
  if (h < 21) return GreetingBucket.evening;
  return GreetingBucket.night;
}

/// The (non-empty) raw variants for [bucket], `{name}` placeholders intact.
List<String> greetingVariants(GreetingBucket bucket) {
  switch (bucket) {
    case GreetingBucket.lateNight:
      return _lateNight;
    case GreetingBucket.earlyMorning:
      return _earlyMorning;
    case GreetingBucket.morning:
      return _morning;
    case GreetingBucket.afternoon:
      return _afternoon;
    case GreetingBucket.evening:
      return _evening;
    case GreetingBucket.night:
      return _night;
  }
}

/// Substitutes every [greetingNamePlaceholder] in [template] with [name].
///
/// A null, empty, or whitespace-only [name] (and the literal string "null",
/// which is what a careless `'$displayName'` interpolation produces) falls
/// back to [greetingNameFallback], so the result never contains the raw
/// placeholder, a dangling comma, or a doubled space.
String applyGreetingName(String template, String? name) {
  final trimmed = name?.trim() ?? '';
  final safe =
      (trimmed.isEmpty || trimmed.toLowerCase() == 'null') ? greetingNameFallback : trimmed;
  return template.replaceAll(greetingNamePlaceholder, safe);
}

/// Whether the raw variant for a bucket carries a name slot — used by the UI
/// to decide whether to also render the rider's name on its own line.
bool greetingTemplateUsesName(String template) =>
    template.contains(greetingNamePlaceholder);

/// The picked greeting plus whether the rider's name ended up inside it.
///
/// The record screen renders the name in its own large display weight when
/// `usesName` is false, and lets the line carry it when true.
typedef Greeting = ({String line, bool usesName});

/// Picks a casual, time-appropriate greeting for [now].
///
/// Pass [random] (seeded) to make the pick deterministic in tests. The result
/// is never empty and never still contains `{name}`.
Greeting greetingDetailFor(DateTime now, {String? name, math.Random? random}) {
  final variants = greetingVariants(greetingBucketFor(now));
  final rng = random ?? math.Random();
  final template = variants[rng.nextInt(variants.length)];
  return (
    line: applyGreetingName(template, name),
    usesName: greetingTemplateUsesName(template),
  );
}

/// Picks a casual, time-appropriate greeting line.
///
/// See [greetingDetailFor] when the caller also needs to know whether the
/// name was woven into the line.
String greetingFor(DateTime now, {String? name, math.Random? random}) =>
    greetingDetailFor(now, name: name, random: random).line;
