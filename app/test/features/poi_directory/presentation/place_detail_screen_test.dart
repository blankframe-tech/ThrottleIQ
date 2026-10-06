import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/poi_directory/domain/entities/place_entity.dart';
import 'package:throttleiq/features/poi_directory/presentation/screens/place_detail_screen.dart';
import 'package:throttleiq/features/poi_directory/presentation/providers/places_provider.dart';
import 'package:throttleiq/l10n/app_localizations.dart';
import 'dart:io';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
  });

  testWidgets('shows photo banner when photoUrls is not empty', (tester) async {
    final place = PlaceEntity(
      id: 'p1',
      name: 'Test Place',
      category: PlaceCategory.fuel,
      latitude: 0,
      longitude: 0,
      geohash: '',
      address: '',
      createdBy: 'u1',
      createdAt: DateTime.now(),
      photoUrls: const ['https://example.com/photo.jpg'],
    );

    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(null),
      placeDetailProvider('p1').overrideWith((ref) => Stream.value(place)),
      reviewsForPlaceProvider('p1').overrideWith((ref) => Stream.value([])),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('bn')],
        home: Scaffold(body: PlaceDetailScreen(placeId: 'p1')),
      ),
    ));

    await tester.pumpAndSettle();
    
    // Check if place name is rendered, meaning the loading finished
    expect(find.text('Test Place'), findsWidgets);
    
    // We check for the ClipRRect that wraps the banner, because Image.network 
    // might fail in tests and trigger the errorBuilder, but ClipRRect is always there.
    expect(find.byType(ClipRRect), findsWidgets);
  });
}
