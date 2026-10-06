import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/shared/widgets/user_avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  testWidgets('UserAvatar falls back to initials when no photoUrl', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            name: 'John Doe',
          ),
        ),
      ),
    );

    expect(find.text('JD'), findsOneWidget);
  });
  
  testWidgets('UserAvatar displays CachedNetworkImage when photoUrl exists', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            name: 'John Doe',
            photoUrl: 'https://example.com/photo.png',
          ),
        ),
      ),
    );
    
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });
}
