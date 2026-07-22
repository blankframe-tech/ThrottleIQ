/// Uppercase initials for a GitHub-style fallback avatar, e.g.
/// `initialsFrom('John Doe')` -> `'JD'`, `initialsFrom('@yamaha_rider')` ->
/// `'Y'`. Falls back to `'R'` (Rider) for an empty/blank name.
String initialsFrom(String name) {
  final source = name.replaceFirst('@', '').trim();
  if (source.isEmpty) return 'R';
  final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'R';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}
