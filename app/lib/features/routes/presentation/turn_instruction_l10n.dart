import '../../../l10n/app_localizations.dart';
import '../domain/turn_instruction.dart';

/// Turn-by-turn banner text in the rider's language.
///
/// The domain engine keeps its English `text` (tests and diagnostics read it);
/// the banner is rebuilt here from the instruction's `kind` and bearing.
extension TurnInstructionL10n on TurnInstruction {
  String localizedText(AppLocalizations l) => switch (kind) {
        TurnKind.start => text.startsWith('Head ')
            ? l.turnHead(_compass(l, compassDirection(bearingDeg)))
            : l.turnStart,
        TurnKind.slightLeft => l.turnSlightLeft,
        TurnKind.left => l.turnLeft,
        TurnKind.sharpLeft => l.turnSharpLeft,
        TurnKind.slightRight => l.turnSlightRight,
        TurnKind.right => l.turnRight,
        TurnKind.sharpRight => l.turnSharpRight,
        TurnKind.uTurn => l.turnUTurn,
        TurnKind.straight => l.turnStraight,
        TurnKind.arrive => l.turnArrive,
      };
}

String _compass(AppLocalizations l, String name) => switch (name) {
      'north' => l.compassNorth,
      'north-east' => l.compassNorthEast,
      'east' => l.compassEast,
      'south-east' => l.compassSouthEast,
      'south' => l.compassSouth,
      'south-west' => l.compassSouthWest,
      'west' => l.compassWest,
      'north-west' => l.compassNorthWest,
      _ => name,
    };
