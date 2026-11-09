import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/services/weather_service.dart';

void main() {
  test('sends the ride start rounded to 2 decimals (~1 km), never exact',
      () async {
    Map<String, dynamic>? query;
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, h) {
        query = options.queryParameters;
        h.resolve(Response(requestOptions: options, data: {
          'hourly': {
            'time': ['2026-11-08T10:00'],
            'temperature_2m': [27.5],
            'weathercode': [1],
          },
        }));
      }));

    final weather = await WeatherService(dio: dio).fetchForRide(
      lat: 23.810331234,
      lng: 90.412518765,
      at: DateTime(2026, 11, 8, 10),
    );

    expect(weather, isNotNull);
    expect(query!['latitude'], 23.81);
    expect(query!['longitude'], 90.41);
    for (final key in ['latitude', 'longitude']) {
      final decimals = query![key].toString().split('.').last;
      expect(decimals.length, lessThanOrEqualTo(2), reason: key);
    }
  });
}
