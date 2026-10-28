import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netmonitor/heatmap_page.dart';
import 'package:netmonitor/main.dart';

void main() {
  group('locationPositions', () {
    test('has a key for every campusLocations name with coordinates in 0..1', () {
      for (final loc in campusLocations) {
        expect(locationPositions.containsKey(loc), isTrue,
            reason: '$loc should be present in locationPositions');
        final pos = locationPositions[loc]!;
        expect(pos.dx >= 0.0 && pos.dx <= 1.0, isTrue,
            reason: '$loc dx must be in 0..1');
        expect(pos.dy >= 0.0 && pos.dy <= 1.0, isTrue,
            reason: '$loc dy must be in 0..1');
      }
    });
  });

  group('scoreColor & scoreLabel', () {
    test('scoreColor matches thresholds', () {
      expect(scoreColor(null), Colors.grey);
      expect(scoreColor(75), Colors.green);
      expect(scoreColor(70), Colors.green);
      expect(scoreColor(55), Colors.amber);
      expect(scoreColor(40), Colors.amber);
      expect(scoreColor(39.9), Colors.red);
    });

    test('scoreLabel matches thresholds', () {
      expect(scoreLabel(null), 'Belum ada data');
      expect(scoreLabel(75), 'Baik');
      expect(scoreLabel(70), 'Baik');
      expect(scoreLabel(55), 'Cukup');
      expect(scoreLabel(40), 'Cukup');
      expect(scoreLabel(39.9), 'Buruk');
    });
  });

  group('buildLocationStats', () {
    test('returns 15 entries, aggregates complete and incomplete samples properly', () {
      final records = [
        const SurveyRecord(
          location: 'Kantin',
          timestamp: '2026-10-28T00:00:00',
          ssid: 'TestNet',
          rssi: -60,
          ip: '10.0.0.1',
          ping: 20.0,
          download: 40.0,
          upload: 15.0,
          note: '',
        ),
        const SurveyRecord(
          location: 'Kantin',
          timestamp: '2026-10-28T00:05:00',
          ssid: 'TestNet',
          rssi: -65,
          ip: '10.0.0.1',
          ping: 50.0,
          download: 20.0,
          upload: 8.0,
          note: '',
        ),
        const SurveyRecord(
          location: 'Kantin',
          timestamp: '2026-10-28T00:10:00',
          ssid: 'TestNet',
          rssi: -70,
          ip: '10.0.0.1',
          ping: 30.0,
          download: null, // Incomplete record
          upload: 5.0,
          note: '',
        ),
      ];

      final stats = buildLocationStats(records);
      expect(stats.length, 15);
      expect(stats.containsKey('Kantin'), isTrue);

      final kantinStats = stats['Kantin']!;
      expect(kantinStats.samples, 3);
      expect(kantinStats.completeSamples, 2);

      // Score should only be the average of the 2 complete records
      final s1 = surveyScore(records[0])!;
      final s2 = surveyScore(records[1])!;
      final expectedScore = (s1 + s2) / 2;
      expect(kantinStats.score, closeTo(expectedScore, 0.001));

      // Other locations should have 0 samples
      final masjidStats = stats['Belakang masjid']!;
      expect(masjidStats.samples, 0);
      expect(masjidStats.completeSamples, 0);
      expect(masjidStats.score, isNull);
    });
  });

  group('HeatmapView widget tests', () {
    testWidgets('renders heatmap, 15 markers, and opens bottom sheet on tap', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final records = [
        const SurveyRecord(
          location: 'Kantin',
          timestamp: '2026-10-28T00:00:00',
          ssid: 'TestNet',
          rssi: -60,
          ip: '10.0.0.1',
          ping: 20.0,
          download: 40.0,
          upload: 15.0,
          note: 'Sample',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeatmapView(records: records),
          ),
        ),
      );

      // Title
      expect(find.text('Peta kualitas WiFi'), findsOneWidget);

      // Finds 15 marker numbers ('1'..'15')
      for (var i = 1; i <= 15; i++) {
        expect(find.text('$i'), findsAtLeastNWidgets(1));
      }

      // Tap marker '3' (Kantin)
      final marker3 = find.text('3').first;
      await tester.tap(marker3);
      await tester.pumpAndSettle();

      // Bottom sheet displays Kantin and metric labels
      expect(find.text('Kantin'), findsAtLeastNWidgets(1));
      expect(find.text('Skor rata-rata'), findsOneWidget);
      expect(find.text('Jumlah sampel (lengkap / total)'), findsOneWidget);
    });
  });
}
