import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/core/theme/theme_style_provider.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/chat/domain/entities/chat_entity.dart';
import 'package:throttleiq/features/chat/presentation/providers/chat_providers.dart';
import 'package:throttleiq/features/chat/presentation/screens/chat_room_screen.dart';
import 'package:throttleiq/features/profile/domain/entities/user_profile_entity.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

class _Me extends Fake implements User {
  @override
  String get uid => 'me';
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// issues §101.A4: own-message bubbles are palette.primary with white text,
/// 1.18:1 on sport/dark lime; others' bubbles had no long-press hint.
void main() {
  testWidgets('own bubble text is readable on sport/dark; others get a report hint',
      (tester) async {
    final handle = tester.ensureSemantics();
    final t = DateTime(2026, 1, 1, 9, 30);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => _Me()),
        chatMessagesProvider('c1').overrideWith((ref) => Stream.value([
              MessageEntity(id: 'm1', senderId: 'me', text: 'mine', createdAt: t),
              MessageEntity(id: 'm2', senderId: 'other', text: 'theirs', createdAt: t),
            ])),
        singleChatProvider('c1').overrideWith((ref) async => null),
        chatBlockedProvider('other').overrideWith((ref) async => false),
      ],
      child: MaterialApp(
        theme: AppTheme.build(const AppAppearance(
          colorMode: AppColorMode.sport,
          shapeVibe: AppShapeVibe.boxy,
          brightness: Brightness.dark,
        )),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ChatRoomScreen(
          chatId: 'c1',
          otherUser: UserProfileEntity(uid: 'other', displayName: 'Other'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    const palette = AppColorPalette.carbonMonoDark;
    final mine = tester.widget<Text>(find.text('mine'));
    expect(mine.style?.color, AppTheme.primaryButtonForeground(palette));
    expect(_contrast(mine.style!.color!, palette.primary),
        greaterThanOrEqualTo(4.5));

    final theirs = tester.getSemantics(find.text('theirs'));
    // A hint override travels as an overriding custom action.
    final reportHint = CustomSemanticsAction.getIdentifier(
      const CustomSemanticsAction.overridingAction(
        hint: 'Report',
        action: SemanticsAction.longPress,
      ),
    );
    expect(theirs.getSemanticsData().customSemanticsActionIds,
        contains(reportHint));
    handle.dispose();
  });
}
