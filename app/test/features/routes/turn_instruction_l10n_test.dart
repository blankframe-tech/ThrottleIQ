import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/routes/domain/turn_instruction.dart';
import 'package:throttleiq/features/routes/presentation/turn_instruction_l10n.dart';
import 'package:throttleiq/l10n/app_localizations_bn.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

void main() {
  final en = AppLocalizationsEn();
  final bn = AppLocalizationsBn();

  TurnInstruction of(TurnKind kind, {double bearing = 47, String? text}) => TurnInstruction(
        pointIndex: 1,
        kind: kind,
        bearingDeg: bearing,
        distanceFromStartM: 100,
        text: text ?? turnText(kind),
      );

  test('English matches the domain wording for every manoeuvre', () {
    for (final k in TurnKind.values.where((k) => k != TurnKind.start)) {
      expect(of(k).localizedText(en), turnText(k), reason: '$k');
    }
  });

  test('the start banner names the compass direction, in both languages', () {
    final start = of(TurnKind.start, bearing: 47, text: 'Head ${compassDirection(47)}');
    expect(start.localizedText(en), 'Head north-east');
    expect(start.localizedText(bn), contains('উত্তর-পূর্ব'));
    expect(start.localizedText(bn), isNot(contains('{')));
  });

  test('Bangla never falls back to English', () {
    for (final k in TurnKind.values) {
      expect(of(k, text: 'Head north').localizedText(bn), isNot(turnText(k)), reason: '$k');
    }
  });
}
