/// Project decision: **digits stay Western (0-9) in every UI language,
/// including Bangla.**
///
/// `intl` will happily render Bengali numerals (০১২৩) once the ambient locale
/// is `bn`, and for prose that would be the more "correct" localisation. We
/// deliberately don't, because:
///
///  * Speed, distance, lean angle and odometer readings are safety-relevant
///    and read at a glance, often mid-ride with a helmet on. Numeral shape is
///    the single most latency-sensitive thing on those screens, and a rider's
///    glance-recognition is trained on whichever form they see most.
///  * In Bangladesh that form is Western: speedometer clusters, road signs,
///    fuel-pump displays, number plates and the odometer the rider is
///    cross-checking us against all use 0-9.
///  * Half-and-half is the worst outcome. If prose said "৬০ সেকেন্ড" while the
///    speed tile said "60", the app would be teaching two numeral systems at
///    once. So the rule is applied to prose in the ARB files too — the Bangla
///    strings are written with ASCII digits on purpose.
///
/// Anything that formats a number or a date for display should pass
/// [kNumericLocale] rather than relying on the ambient locale. Bangla ARB
/// strings should be authored with ASCII digits.
///
/// If this is ever revisited, revisit it *only* for non-safety prose (e.g. a
/// blog-style article body) and leave instrument readouts alone.
library;

/// Locale tag used for every user-visible number/date formatter, regardless of
/// the UI language. See the library doc comment for why.
const String kNumericLocale = 'en';
