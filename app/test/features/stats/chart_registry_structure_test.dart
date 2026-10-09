// Why this test exists: the Rides-tab analytics charts used to be one
// `AnalyticsChart` enum that three shared files switched over (series math,
// shape, unit, colour, title, insight, table/CSV columns...). Every new chart
// edited the same `switch` arms, so when two features were built in parallel
// (lean/g/elevation and fuel) every one of those arms conflicted.
//
// Now each chart family is one file under `domain/charts/` plus one under
// `presentation/charts/`, listed by one line in each layer's registry. This
// test keeps it that way: the shared files may not name any chart or any
// symbol a family file declares, the registries may only list, and every
// registered chart must have a unique id and a title in English and Bangla.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/stats/domain/analytics_chart_registry.dart';
import 'package:throttleiq/features/stats/presentation/analytics_chart_registry.dart';
import 'package:throttleiq/l10n/app_localizations_bn.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

const _stats = 'lib/features/stats';

/// Generic analytics machinery: must stay chart-agnostic.
const _sharedFiles = [
  '$_stats/domain/ride_analytics.dart',
  '$_stats/presentation/analytics_chart_l10n.dart',
  '$_stats/presentation/widgets/analytics_chart_view.dart',
  '$_stats/presentation/widgets/analytics_chart_card.dart',
  '$_stats/presentation/screens/analytics_detail_screen.dart',
  '$_stats/presentation/screens/stats_screen.dart',
];

/// Each layer's ordered list, and the folder of family files it lists.
const _registries = {
  '$_stats/domain/analytics_chart_registry.dart': '$_stats/domain/charts',
  '$_stats/presentation/analytics_chart_registry.dart':
      '$_stats/presentation/charts',
};

String _withoutComments(String source) =>
    source.replaceAll(RegExp(r'//.*$', multiLine: true), '');

/// Public top-level names a family file declares: its family class, its
/// insight kinds, its helpers and its presentation list.
Set<String> _declaredNames(String source) {
  final names = <String>{};
  final patterns = [
    RegExp(r'^(?:abstract\s+|final\s+|base\s+|sealed\s+)*class\s+(\w+)',
        multiLine: true),
    RegExp(r'^(?:const|final|var)\s+(?:[\w<>?,\s]+?\s+)?(\w+)\s*=',
        multiLine: true),
    RegExp(
        r'^(?!import|export|library|part|class|abstract|final|const|var|typedef|enum|extension|mixin)\S.*?\s(\w+)\s*\(',
        multiLine: true),
  ];
  for (final p in patterns) {
    for (final m in p.allMatches(_withoutComments(source))) {
      final name = m.group(1)!;
      if (!name.startsWith('_')) names.add(name);
    }
  }
  return names;
}

List<File> _dartFilesIn(String dir) =>
    Directory(dir).listSync().whereType<File>().where((f) {
      return f.path.endsWith('.dart');
    }).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Every way [source] names a specific chart or family, as messages.
List<String> _chartReferences(
  String source, {
  required Set<String> ids,
  required Set<String> familySymbols,
}) {
  final code = _withoutComments(source);
  final found = <String>[];
  for (final m in RegExp(r'AnalyticsChart\.([a-z]\w*)').allMatches(code)) {
    found.add('enum-style chart reference AnalyticsChart.${m.group(1)}');
  }
  if (RegExp(r'''import\s+['"](?:[^'"]*/)?charts/''').hasMatch(code)) {
    found.add('imports a chart family file directly');
  }
  for (final id in ids) {
    if (RegExp('[\'"]$id[\'"]').hasMatch(code)) {
      found.add("chart id '$id' as a string");
    }
    // `.weekday` on a DateTime is fine; a bare `weekday` identifier is not.
    if (RegExp('(?<![.\\w])$id\\b').hasMatch(code)) {
      found.add('chart id $id as an identifier');
    }
  }
  for (final s in familySymbols) {
    if (RegExp('(?<![.\\w])$s\\b').hasMatch(code)) {
      found.add('family symbol $s');
    }
  }
  return found;
}

void main() {
  final ids = {for (final c in analyticsCharts) c.id};
  final familySymbols = <String>{
    for (final dir in _registries.values)
      for (final f in _dartFilesIn(dir))
        ..._declaredNames(f.readAsStringSync()),
  };

  test('the family files declare something to guard against', () {
    expect(familySymbols, containsAll(['FuelCharts', 'fuelPresentations']));
  });

  test('the scanner flags chart-specific code', () {
    for (final snippet in [
      'if (chart == AnalyticsChart.fuelSpend) {}',
      'case FuelCharts.fuelSpend:',
      "final c = byId['peakG'];",
      'final s = weekday;',
      "import 'charts/fuel_charts.dart';",
    ]) {
      expect(_chartReferences(snippet, ids: ids, familySymbols: familySymbols),
          isNotEmpty,
          reason: snippet);
    }
    expect(
        _chartReferences('final d = date.weekday; // FuelCharts in prose',
            ids: ids, familySymbols: familySymbols),
        isEmpty);
  });

  for (final path in _sharedFiles) {
    test('$path names no specific chart', () {
      final found = _chartReferences(File(path).readAsStringSync(),
          ids: ids, familySymbols: familySymbols);
      expect(found, isEmpty,
          reason: 'Shared analytics code must stay chart-agnostic. Move '
              'chart-specific behaviour into the family file under charts/ '
              '(a field or override on its AnalyticsChart / '
              'ChartPresentation).');
    });
  }

  _registries.forEach((registry, familyDir) {
    test('$registry only lists, and lists every family', () {
      final code = _withoutComments(File(registry).readAsStringSync());
      expect(RegExp(r'\b(switch|case)\b|\bif\s*\(').hasMatch(code), isFalse,
          reason: 'A registry is an ordered list, not a dispatcher.');
      for (final f in _dartFilesIn(familyDir)) {
        final name = f.uri.pathSegments.last;
        expect(code, contains("'charts/$name'"),
            reason: '$name is not registered');
      }
    });
  });

  test('every chart has a unique, non-empty id', () {
    expect(analyticsCharts, isNotEmpty);
    for (final c in analyticsCharts) {
      expect(c.id.trim(), isNotEmpty);
    }
    expect(ids.length, analyticsCharts.length, reason: 'duplicate chart id');
  });

  test('both registries list the same charts in the same order', () {
    expect([for (final p in analyticsChartPresentations) p.chart.id],
        [for (final c in analyticsCharts) c.id]);
    for (final c in analyticsCharts) {
      expect(identical(chartPresentationOf(c).chart, c), isTrue, reason: c.id);
    }
  });

  test('every chart has a title in en and bn', () {
    for (final l10n in [AppLocalizationsEn(), AppLocalizationsBn()]) {
      for (final p in analyticsChartPresentations) {
        expect(p.title(l10n).trim(), isNotEmpty,
            reason: '${p.chart.id} (${l10n.localeName})');
        expect(() => p.unit(l10n), returnsNormally, reason: p.chart.id);
      }
    }
  });
}
