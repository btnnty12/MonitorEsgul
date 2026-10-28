import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'main.dart';

Color scoreColor(double? score) {
  if (score == null) return Colors.grey;
  if (score >= 70) return Colors.green;
  if (score >= 40) return Colors.amber;
  return Colors.red;
}

String scoreLabel(double? score) {
  if (score == null) return 'Belum ada data';
  if (score >= 70) return 'Baik';
  if (score >= 40) return 'Cukup';
  return 'Buruk';
}

const locationPositions = <String, Offset>{
  'Pintu belakang Universitas Esa Unggul': Offset(0.50, 0.05),
  'Danau jauh': Offset(0.88, 0.10),
  'Belakang masjid': Offset(0.15, 0.14),
  'Gedung Teknik': Offset(0.80, 0.27),
  'Ballroom': Offset(0.20, 0.32),
  'Lapangan': Offset(0.50, 0.38),
  'Gedung E': Offset(0.82, 0.47),
  'Perpustakaan': Offset(0.18, 0.50),
  'Kantin': Offset(0.42, 0.56),
  'Esa Corner': Offset(0.62, 0.60),
  'Gedung C': Offset(0.84, 0.66),
  'Lantai 8 Gedung A': Offset(0.30, 0.72),
  'Lobby Gedung A': Offset(0.50, 0.78),
  'Parkiran sebelah klinik': Offset(0.12, 0.86),
  'Parkiran depan': Offset(0.62, 0.92),
};

class LocationStats {
  final String location;
  final int samples;          // all saved records at this location
  final int completeSamples;  // records where surveyScore != null
  final double? score;        // average heuristic score of complete records
  final double? ping;         // average ping of non-null values
  final double? download;     // average download of non-null values
  final double? upload;       // average upload of non-null values
  final double? rssi;         // average RSSI of non-null values

  const LocationStats({
    required this.location,
    required this.samples,
    required this.completeSamples,
    this.score,
    this.ping,
    this.download,
    this.upload,
    this.rssi,
  });
}

Map<String, LocationStats> buildLocationStats(List<SurveyRecord> records) {
  final result = <String, LocationStats>{};
  for (final location in campusLocations) {
    final locRecords = records.where((r) => r.location == location).toList();
    final samples = locRecords.length;

    final completeRecords = locRecords.where((r) => surveyScore(r) != null).toList();
    final completeSamples = completeRecords.length;
    final score = completeRecords.isEmpty
        ? null
        : completeRecords.map((r) => surveyScore(r)!).reduce((a, b) => a + b) / completeRecords.length;

    final pings = locRecords.map((r) => r.ping).whereType<double>().toList();
    final ping = pings.isEmpty ? null : pings.reduce((a, b) => a + b) / pings.length;

    final downloads = locRecords.map((r) => r.download).whereType<double>().toList();
    final download = downloads.isEmpty ? null : downloads.reduce((a, b) => a + b) / downloads.length;

    final uploads = locRecords.map((r) => r.upload).whereType<double>().toList();
    final upload = uploads.isEmpty ? null : uploads.reduce((a, b) => a + b) / uploads.length;

    final rssis = locRecords.map((r) => r.rssi?.toDouble()).whereType<double>().toList();
    final rssi = rssis.isEmpty ? null : rssis.reduce((a, b) => a + b) / rssis.length;

    result[location] = LocationStats(
      location: location,
      samples: samples,
      completeSamples: completeSamples,
      score: score,
      ping: ping,
      download: download,
      upload: upload,
      rssi: rssi,
    );
  }
  return result;
}

class HeatmapView extends StatelessWidget {
  final List<SurveyRecord> records;
  final VoidCallback? onSeedSampleData;

  const HeatmapView({
    super.key,
    required this.records,
    this.onSeedSampleData,
  });

  @override
  Widget build(BuildContext context) {
    final statsMap = buildLocationStats(records);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Peta kualitas WiFi',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        const Text(
          'Denah skematis, bukan skala sebenarnya. Warna dari rata-rata skor hasil lengkap.',
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final glowSize = (width * 0.22).clamp(56.0, 76.0);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CampusPlanPainter(),
                      ),
                    ),
                    ...campusLocations.asMap().entries.map((entry) {
                      final index = entry.key;
                      final name = entry.value;
                      final pos = locationPositions[name] ?? const Offset(0.5, 0.5);
                      final stats = statsMap[name] ?? LocationStats(
                        location: name,
                        samples: 0,
                        completeSamples: 0,
                      );
                      final color = scoreColor(stats.score);
                      final centerX = pos.dx * width;
                      final centerY = pos.dy * height;

                      return Positioned(
                        left: centerX - glowSize / 2,
                        top: centerY - glowSize / 2,
                        width: glowSize,
                        height: glowSize,
                        child: Center(
                          child: Container(
                            width: glowSize,
                            height: glowSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  color.withValues(alpha: 0.45),
                                  color.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Tooltip(
                                message: name,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _showLocationSheet(context, index, stats),
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: color,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: color == Colors.amber ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _legendChip(Colors.green, 'Baik (≥ 70)'),
            _legendChip(Colors.amber, 'Cukup (40–69)'),
            _legendChip(Colors.red, 'Buruk (< 40)'),
            _legendChip(Colors.grey, 'Belum ada data'),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: campusLocations.asMap().entries.map((entry) {
              final index = entry.key;
              final name = entry.value;
              final stats = statsMap[name] ?? LocationStats(
                location: name,
                samples: 0,
                completeSamples: 0,
              );
              final color = scoreColor(stats.score);

              return ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: color,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: color == Colors.amber ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(name),
                subtitle: Text(
                  '${scoreLabel(stats.score)} · skor ${stats.score?.toStringAsFixed(1) ?? '-'} · ${stats.samples} sampel',
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _showLocationSheet(context, index, stats),
              );
            }).toList(),
          ),
        ),
        if (kDebugMode && onSeedSampleData != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onSeedSampleData,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Isi data contoh (hanya mode debug)'),
          ),
        ],
      ],
    );
  }

  Widget _legendChip(Color color, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );

  void _showLocationSheet(BuildContext context, int index, LocationStats stats) {
    final color = scoreColor(stats.score);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: color == Colors.amber ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      stats.location,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      scoreLabel(stats.score),
                      style: TextStyle(
                        color: color == Colors.amber ? Colors.orange.shade900 : color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sheetMetricRow(
                'Skor rata-rata',
                stats.score == null ? '-' : '${stats.score!.toStringAsFixed(1)} / 100',
              ),
              _sheetMetricRow(
                'Jumlah sampel (lengkap / total)',
                '${stats.completeSamples} / ${stats.samples}',
              ),
              _sheetMetricRow('Ping rata-rata', fmt(stats.ping, suffix: ' ms')),
              _sheetMetricRow('Download rata-rata', fmt(stats.download, suffix: ' Mbps')),
              _sheetMetricRow('Upload rata-rata', fmt(stats.upload, suffix: ' Mbps')),
              _sheetMetricRow('RSSI rata-rata', fmt(stats.rssi, suffix: ' dBm', digits: 0)),
              const SizedBox(height: 12),
              Text(
                'Ambil beberapa sampel pada jam ramai dan sepi agar hasil lebih akurat.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetMetricRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

class _CampusPlanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background base
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Main walkway path (front gate to back gate)
    final pathPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final mainPath = Path()
      ..moveTo(w * 0.50, h * 0.96)
      ..lineTo(w * 0.50, h * 0.05);
    canvas.drawPath(mainPath, pathPaint);

    // Branch walkways
    final branchPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final branchPath = Path()
      ..moveTo(w * 0.18, h * 0.50)
      ..lineTo(w * 0.82, h * 0.50)
      ..moveTo(w * 0.20, h * 0.32)
      ..lineTo(w * 0.80, h * 0.27)
      ..moveTo(w * 0.30, h * 0.72)
      ..lineTo(w * 0.84, h * 0.66);
    canvas.drawPath(branchPath, branchPaint);

    // Lake (Danau jauh)
    final lakePaint = Paint()
      ..color = const Color(0xFFBBDEFB)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.88, h * 0.10), width: w * 0.18, height: h * 0.08),
      lakePaint,
    );
    _drawLabel(canvas, 'Danau', Offset(w * 0.88, h * 0.10));

    // Lapangan (Field)
    final fieldPaint = Paint()
      ..color = const Color(0xFFC8E6C9)
      ..style = PaintingStyle.fill;
    final fieldRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.38), width: w * 0.30, height: h * 0.08),
      const Radius.circular(8),
    );
    canvas.drawRRect(fieldRect, fieldPaint);
    _drawLabel(canvas, 'Lapangan', Offset(w * 0.50, h * 0.38));

    // Parking lots
    final parkPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.fill;

    final parkDepan = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.62, h * 0.92), width: w * 0.32, height: h * 0.07),
      const Radius.circular(6),
    );
    canvas.drawRRect(parkDepan, parkPaint);
    _drawLabel(canvas, 'Parkiran Depan', Offset(w * 0.62, h * 0.92));

    final parkKlinik = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.14, h * 0.86), width: w * 0.22, height: h * 0.07),
      const Radius.circular(6),
    );
    canvas.drawRRect(parkKlinik, parkPaint);
    _drawLabel(canvas, 'Parkiran Klinik', Offset(w * 0.14, h * 0.86));

    // Buildings helper
    void drawBuilding(String name, Rect rect) {
      final bldgPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rrect, bldgPaint);
      canvas.drawRRect(rrect, strokePaint);
      _drawLabel(canvas, name, rect.center);
    }

    drawBuilding('Masjid', Rect.fromCenter(center: Offset(w * 0.15, h * 0.14), width: w * 0.22, height: h * 0.06));
    drawBuilding('Gedung Teknik', Rect.fromCenter(center: Offset(w * 0.80, h * 0.27), width: w * 0.24, height: h * 0.07));
    drawBuilding('Ballroom', Rect.fromCenter(center: Offset(w * 0.20, h * 0.32), width: w * 0.22, height: h * 0.06));
    drawBuilding('Perpustakaan', Rect.fromCenter(center: Offset(w * 0.18, h * 0.50), width: w * 0.24, height: h * 0.07));
    drawBuilding('Gedung E', Rect.fromCenter(center: Offset(w * 0.82, h * 0.47), width: w * 0.22, height: h * 0.07));
    drawBuilding('Kantin & Esa Corner', Rect.fromCenter(center: Offset(w * 0.52, h * 0.58), width: w * 0.34, height: h * 0.06));
    drawBuilding('Gedung C', Rect.fromCenter(center: Offset(w * 0.84, h * 0.66), width: w * 0.22, height: h * 0.07));
    drawBuilding('Gedung A', Rect.fromCenter(center: Offset(w * 0.40, h * 0.75), width: w * 0.38, height: h * 0.09));

    // Gate indicators
    _drawLabel(canvas, 'Pintu Belakang', Offset(w * 0.50, h * 0.02));
    _drawLabel(canvas, 'Pintu Utama Depan', Offset(w * 0.50, h * 0.985));
  }

  void _drawLabel(Canvas canvas, String text, Offset center) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
