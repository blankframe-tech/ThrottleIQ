import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/forum_directory.dart';

/// Presentation for [TopicBoard]s: the board names riders see. The forum's
/// stored topic (its identity) stays the plain one in `forum_directory.dart`.
String topicBoardTitle(AppLocalizations l10n, TopicBoard board) {
  switch (board) {
    case TopicBoard.wrenchBench:
      return l10n.boardWrenchBench;
    case TopicBoard.sparkPlugCorner:
      return l10n.boardSparkPlug;
    case TopicBoard.apexLab:
      return l10n.boardApexLab;
    case TopicBoard.twoStrokeSmoke:
      return l10n.boardTwoStroke;
    case TopicBoard.engineRebuild:
      return l10n.boardEngineRebuild;
    case TopicBoard.oilReviews:
      return l10n.boardOilReviews;
    case TopicBoard.dirtTrails:
      return l10n.boardDirtTrails;
    case TopicBoard.mileageLab:
      return l10n.boardMileageLab;
  }
}

String topicBoardBlurb(AppLocalizations l10n, TopicBoard board) {
  switch (board) {
    case TopicBoard.wrenchBench:
      return l10n.boardWrenchBenchBlurb;
    case TopicBoard.sparkPlugCorner:
      return l10n.boardSparkPlugBlurb;
    case TopicBoard.apexLab:
      return l10n.boardApexLabBlurb;
    case TopicBoard.twoStrokeSmoke:
      return l10n.boardTwoStrokeBlurb;
    case TopicBoard.engineRebuild:
      return l10n.boardEngineRebuildBlurb;
    case TopicBoard.oilReviews:
      return l10n.boardOilReviewsBlurb;
    case TopicBoard.dirtTrails:
      return l10n.boardDirtTrailsBlurb;
    case TopicBoard.mileageLab:
      return l10n.boardMileageLabBlurb;
  }
}

IconData topicBoardIcon(TopicBoard board) {
  switch (board) {
    case TopicBoard.wrenchBench:
      return Icons.build_outlined;
    case TopicBoard.sparkPlugCorner:
      return Icons.bolt_outlined;
    case TopicBoard.apexLab:
      return Icons.sports_score_outlined;
    case TopicBoard.twoStrokeSmoke:
      return Icons.air;
    case TopicBoard.engineRebuild:
      return Icons.settings_outlined;
    case TopicBoard.oilReviews:
      return Icons.opacity;
    case TopicBoard.dirtTrails:
      return Icons.terrain_outlined;
    case TopicBoard.mileageLab:
      return Icons.local_gas_station_outlined;
  }
}
