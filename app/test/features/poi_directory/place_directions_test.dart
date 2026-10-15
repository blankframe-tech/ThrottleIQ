import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/poi_directory/domain/place_directions.dart';

/// The URL building behind a place's "Directions" / "Call" buttons.
///
/// Pure by design so it's testable without platform channels — the launch
/// itself is one `launchUrl` call in the widget, which a unit test can't
/// exercise anyway.
void main() {
  group('googleMapsDirectionsUri', () {
    test('targets coordinates, in driving mode', () {
      final uri = googleMapsDirectionsUri(latitude: 23.7925361, longitude: 90.4078212);

      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['travelmode'], 'driving');
      expect(uri.queryParameters['destination'], '23.7925361,90.4078212');
    });

    test('does NOT put the place name in the URL', () {
      // The dir/?api=1 form treats a text destination as a search query, so a
      // name could resolve to a different branch than the one tapped. There is
      // no name parameter to pass, and this pins that.
      final uri = googleMapsDirectionsUri(latitude: 1.5, longitude: 2.5);
      expect(uri.queryParameters.keys.toSet(),
          {'api', 'destination', 'travelmode'});
    });

    test('formats negative and small coordinates without exponent notation', () {
      // A double like 1e-7 stringifies as "1e-7", which no maps URL accepts.
      final uri = googleMapsDirectionsUri(latitude: -0.0000001, longitude: -73.9);
      expect(uri.queryParameters['destination'], isNot(contains('e')));
      expect(uri.queryParameters['destination'], '-0.0000001,-73.9000000');
    });
  });

  group('appleMapsDirectionsUri', () {
    test('sets the destination, driving flag and a pin label', () {
      final uri = appleMapsDirectionsUri(
        latitude: 23.79,
        longitude: 90.41,
        label: 'Shell Petrol Pump',
      );

      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['daddr'], '23.7900000,90.4100000');
      expect(uri.queryParameters['ll'], '23.7900000,90.4100000');
      expect(uri.queryParameters['dirflg'], 'd');
      expect(uri.queryParameters['q'], 'Shell Petrol Pump');
    });

    test('omits the label when it is null or blank', () {
      final noLabel = appleMapsDirectionsUri(latitude: 1, longitude: 2);
      expect(noLabel.queryParameters.containsKey('q'), isFalse);

      final blank = appleMapsDirectionsUri(latitude: 1, longitude: 2, label: '   ');
      expect(blank.queryParameters.containsKey('q'), isFalse);
    });
  });

  group('telUri', () {
    test('strips the punctuation Bangladeshi numbers are written with', () {
      expect(telUri('+880 1712-345678')?.toString(), 'tel:+8801712345678');
      expect(telUri('(02) 9887 766')?.toString(), 'tel:029887766');
    });

    test('keeps a leading + so international numbers dial', () {
      expect(telUri('+8801712345678')?.path, '+8801712345678');
      expect(telUri('01712345678')?.path, '01712345678');
    });

    test('returns null when there is nothing dialable', () {
      // The caller hides the Call button on null rather than opening an empty
      // dialler.
      expect(telUri(null), isNull);
      expect(telUri(''), isNull);
      expect(telUri('   '), isNull);
      expect(telUri('call us!'), isNull);
    });
  });
}
