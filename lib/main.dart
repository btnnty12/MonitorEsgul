import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

const campusLocations = <String>[
  'Belakang masjid',
  'Gedung Teknik',
  'Kantin',
  'Perpustakaan',
  'Esa Corner',
  'Parkiran sebelah klinik',
  'Pintu belakang Universitas Esa Unggul',
  'Ballroom',
  'Lapangan',
  'Gedung C',
  'Danau jauh',
  'Lobby Gedung A',
  'Lantai 8 Gedung A',
  'Parkiran depan',
  'Gedung E',
];

const wifiChannel = MethodChannel('netmonitor/wifi');

Future<Map<String, dynamic>> readWifi() async {
  try {
    final result = await wifiChannel.invokeMapMethod<String, dynamic>('getWifiInfo');
    return result ?? {'ssid': 'Tidak tersedia', 'rssi': null, 'ip': '-'};
  } on PlatformException {
    return {'ssid': 'Tidak tersedia', 'rssi': null, 'ip': '-'};
  }
}

Future<double?> measureTcpLatency() async {
  final watch = Stopwatch()..start();
  try {
    final socket = await Socket.connect('1.1.1.1', 443,
        timeout: const Duration(seconds: 4));
    watch.stop();
    socket.destroy();
    return watch.elapsedMicroseconds / 1000.0;
  } catch (_) {
    return null;
  }
}

Future<double?> measureDownloadMbps() async {
  HttpClient? client;
  try {
    client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final uri = Uri.parse('https://speed.cloudflare.com/__down?bytes=3000000');
    final watch = Stopwatch()..start();
    final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    var bytes = 0;
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      bytes += chunk.length;
    }
    watch.stop();
    if (bytes == 0 || watch.elapsedMicroseconds == 0) { return null; }
    return bytes * 8 / (watch.elapsedMicroseconds / 1000000) / 1000000;
  } catch (_) {
    return null;
  } finally {
    client?.close(force: true);
  }
}

Future<double?> measureUploadMbps() async {
  HttpClient? client;
  try {
    client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final payload = List<int>.generate(500000, (i) => (i * 31 + 17) % 256);
    final uri = Uri.parse('https://speed.cloudflare.com/__up');
    final watch = Stopwatch()..start();
    final request = await client.postUrl(uri).timeout(const Duration(seconds: 10));
    request.headers.contentType = ContentType.binary;
    request.contentLength = payload.length;
    request.add(payload);
    final response = await request.close().timeout(const Duration(seconds: 20));
    await response.drain<void>();
    watch.stop();
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        watch.elapsedMicroseconds == 0) { return null; }
    return payload.length * 8 / (watch.elapsedMicroseconds / 1000000) / 1000000;
  } catch (_) {
    return null;
  } finally {
    client?.close(force: true);
  }
}

String fmt(double? value, {String suffix = '', int digits = 1}) =>
    value == null ? 'Gagal / tidak tersedia' : '${value.toStringAsFixed(digits)}$suffix';

class SurveyRecord {
  final int? id;
  final String location;
  final String timestamp;
  final String ssid;
  final int? rssi;
  final String ip;
  final double? ping;
  final double? download;
  final double? upload;
  final String note;

  const SurveyRecord({
    this.id,
    required this.location,
    required this.timestamp,
    required this.ssid,
    required this.rssi,
    required this.ip,
    required this.ping,
    required this.download,
    required this.upload,
    required this.note,
  });

  Map<String, Object?> toMap() => {
    'location': location, 'timestamp': timestamp, 'ssid': ssid,
    'rssi': rssi, 'ip': ip, 'ping': ping, 'download': download,
    'upload': upload, 'note': note,
  };

  factory SurveyRecord.fromMap(Map<String, Object?> map) => SurveyRecord(
    id: map['id'] as int?,
    location: map['location'] as String,
    timestamp: map['timestamp'] as String,
    ssid: map['ssid'] as String,
    rssi: map['rssi'] as int?,
    ip: map['ip'] as String,
    ping: (map['ping'] as num?)?.toDouble(),
    download: (map['download'] as num?)?.toDouble(),
    upload: (map['upload'] as num?)?.toDouble(),
    note: map['note'] as String? ?? '',
  );
}

class SurveyDb {
  SurveyDb._();
  static final SurveyDb instance = SurveyDb._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final base = await getDatabasesPath();
    _db = await openDatabase(
      p.join(base, 'netmonitor.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE surveys (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            location TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            ssid TEXT NOT NULL,
            rssi INTEGER,
            ip TEXT NOT NULL,
            ping REAL,
            download REAL,
            upload REAL,
            note TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> insert(SurveyRecord record) async {
    final database = await db;
    await database.insert('surveys', record.toMap());
  }

  Future<List<SurveyRecord>> all() async {
    final database = await db;
    final rows = await database.query('surveys', orderBy: 'id DESC');
    return rows.map(SurveyRecord.fromMap).toList();
  }

  Future<void> delete(int id) async {
    final database = await db;
    await database.delete('surveys', where: 'id = ?', whereArgs: [id]);
  }
}

void main() => runApp(const NetMonitorApp());

class NetMonitorApp extends StatelessWidget {
  const NetMonitorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NetMonitor',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1769AA)),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    ),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  String _location = campusLocations.first;
  Map<String, dynamic> _wifi = {'ssid': 'Belum dibaca', 'rssi': null, 'ip': '-'};
  double? _ping, _download, _upload;
  bool _busy = false;
  String _status = 'Hubungkan HP ke WiFi kampus, lalu mulai survei.';
  final _noteController = TextEditingController();
  List<SurveyRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _refreshWifi();
    _loadHistory();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _refreshWifi() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted && mounted) {
      setState(() => _status =
          'Izin lokasi ditolak. Android mungkin menyembunyikan nama SSID.');
    }
    final info = await readWifi();
    if (mounted) { setState(() => _wifi = info);
    }
  }

  Future<void> _loadHistory() async {
    final rows = await SurveyDb.instance.all();
    if (mounted) setState(() => _history = rows);
  }

  Future<void> _runSurvey() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _ping = null;
      _download = null;
      _upload = null;
      _status = 'Mengukur latency...';
    });
    try {
      await _refreshWifi();
      final ping = await measureTcpLatency();
      if (mounted) { setState(() { _ping = ping; _status = 'Mengukur download...'; }); }
      final down = await measureDownloadMbps();
      if (mounted) { setState(() { _download = down; _status = 'Mengukur upload...'; }); }
      final up = await measureUploadMbps();
      if (mounted) { setState(() {
        _upload = up;
        _status = 'Selesai. Periksa hasil, lalu simpan ke riwayat.';
      }); }
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  Future<void> _saveSurvey() async {
    final record = SurveyRecord(
      location: _location,
      timestamp: DateTime.now().toIso8601String(),
      ssid: (_wifi['ssid'] ?? 'Tidak tersedia').toString(),
      rssi: _wifi['rssi'] is num ? (_wifi['rssi'] as num).toInt() : null,
      ip: (_wifi['ip'] ?? '-').toString(),
      ping: _ping,
      download: _download,
      upload: _upload,
      note: _noteController.text.trim(),
    );
    await SurveyDb.instance.insert(record);
    _noteController.clear();
    await _loadHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasil survei disimpan di HP.')),
      );
      setState(() => _tab = 1);
    }
  }

  double? _score(SurveyRecord r) {
    if (r.ping == null || r.download == null || r.upload == null) return null;
    // Skor heuristik untuk membantu perbandingan, bukan sertifikasi kualitas Zoom.
    final pingScore = (100 - (r.ping! / 2)).clamp(0, 100).toDouble();
    final downScore = (r.download! * 2).clamp(0, 100).toDouble();
    final upScore = (r.upload! * 5).clamp(0, 100).toDouble();
    return pingScore * .35 + downScore * .30 + upScore * .35;
  }

  Map<String, double> _locationScores() {
    final buckets = <String, List<double>>{};
    for (final record in _history) {
      final score = _score(record);
      if (score != null) buckets.putIfAbsent(record.location, () => []).add(score);
    }
    return {
      for (final entry in buckets.entries)
        entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length
    };
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _surveyPage(),
      _historyPage(),
      _recommendationPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.wifi_tethering_rounded),
          SizedBox(width: 10),
          Text('NetMonitor'),
        ]),
        actions: [
          IconButton(
            tooltip: 'Perbarui informasi WiFi',
            onPressed: _refreshWifi,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radar), label: 'Survei'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: 'Rekomendasi'),
        ],
      ),
    );
  }

  Widget _surveyPage() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _introCard(),
      const SizedBox(height: 12),
      Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('1. Pilih lokasi survei', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _location,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Lokasi kampus'),
            items: campusLocations.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
            onChanged: _busy ? null : (value) { if (value != null) setState(() => _location = value); },
          ),
          const SizedBox(height: 16),
          Text('2. Informasi jaringan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _infoRow(Icons.wifi, 'SSID', '${_wifi['ssid'] ?? '-'}'),
          _infoRow(Icons.network_wifi, 'Kekuatan sinyal (RSSI)', _wifi['rssi'] == null ? 'Tidak tersedia' : '${_wifi['rssi']} dBm'),
          _infoRow(Icons.router_outlined, 'IP lokal', '${_wifi['ip'] ?? '-'}'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _refreshWifi,
            icon: const Icon(Icons.refresh),
            label: const Text('Baca ulang informasi WiFi'),
          ),
        ]),
      )),
      const SizedBox(height: 12),
      Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('3. Ukur kualitas koneksi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _metricRow('Latency / TCP connect', fmt(_ping, suffix: ' ms')),
          _metricRow('Download', fmt(_download, suffix: ' Mbps')),
          _metricRow('Upload', fmt(_upload, suffix: ' Mbps')),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          Text(_status, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _runSurvey,
            icon: const Icon(Icons.speed),
            label: Text(_busy ? 'Sedang mengukur...' : 'Mulai pengukuran'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ]),
      )),
      const SizedBox(height: 12),
      Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('4. Catatan kondisi lokasi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Contoh: ramai, dekat stopkontak, cocok untuk rapat...',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _saveSurvey,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan hasil survei'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 6),
          const Text('Simpan setelah pengukuran selesai. Nilai yang gagal akan disimpan sebagai data kosong, bukan nol.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      )),
    ],
  );

  Widget _introCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF1769AA), Color(0xFF123C72)]),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Temukan tempat nyaman untuk Zoom', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      SizedBox(height: 6),
      Text('Ukur WiFi di 15 lokasi kampus. Ulangi pengukuran pada waktu berbeda untuk membandingkan kualitas koneksi.',
          style: TextStyle(color: Colors.white70)),
    ]),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(child: Text(label)),
      const SizedBox(width: 8),
      Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _metricRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Expanded(child: Text(label)),
      Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold))),
    ]),
  );

  Widget _historyPage() => FutureBuilder<List<SurveyRecord>>(
    future: SurveyDb.instance.all(),
    builder: (context, snapshot) {
      final rows = snapshot.data ?? _history;
      if (rows.isEmpty) {
        return const Center(child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Belum ada riwayat. Buka tab Survei untuk mengukur dan menyimpan hasil.'),
        ));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final r = rows[index];
          return Card(
            child: ListTile(
              isThreeLine: true,
              leading: const CircleAvatar(child: Icon(Icons.wifi)),
              title: Text(r.location),
              subtitle: Text(
                '${r.timestamp.replaceFirst('T', ' ').split('.').first}\n'
                'RSSI: ${r.rssi == null ? '-' : '${r.rssi} dBm'} · Ping: ${fmt(r.ping, suffix: ' ms')}\n'
                'Down: ${fmt(r.download, suffix: ' Mbps')} · Up: ${fmt(r.upload, suffix: ' Mbps')}',
              ),
              trailing: IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (r.id != null) await SurveyDb.instance.delete(r.id!);
                  await _loadHistory();
                },
              ),
            ),
          );
        },
      );
    },
  );

  Widget _recommendationPage() {
    final scores = _locationScores().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Rekomendasi lokasi', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Peringkat dihitung dari hasil yang tersimpan dan lengkap. Ini skor heuristik untuk perbandingan awal, bukan jaminan kualitas Zoom. Kumpulkan beberapa sampel per lokasi.'),
        const SizedBox(height: 12),
        if (scores.isEmpty)
          const Card(child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Belum cukup data. Lakukan dan simpan pengukuran dengan ping, download, dan upload berhasil.'),
          ))
        else
          ...scores.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final item = entry.value;
            return Card(child: ListTile(
              leading: CircleAvatar(child: Text('$rank')),
              title: Text(item.key),
              subtitle: Text('Rata-rata skor: ${item.value.toStringAsFixed(1)}/100'),
              trailing: rank == 1 ? const Icon(Icons.emoji_events, color: Colors.amber) : null,
            ));
          }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await _loadHistory();
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Perbarui rekomendasi'),
        ),
      ],
    );
  }
}
