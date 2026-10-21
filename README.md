# NetMonitor Flutter

Aplikasi survei kualitas WiFi kampus untuk membantu mahasiswa memilih lokasi yang nyaman untuk Zoom/rapat online.

## Fitur
- 15 lokasi survei kampus yang telah ditentukan.
- Membaca SSID, RSSI (dBm), dan IP lokal melalui Android MethodChannel.
- Estimasi latency dengan TCP connect ke `1.1.1.1:443`.
- Estimasi download/upload memakai endpoint publik Cloudflare Speed Test.
- Menyimpan riwayat secara lokal menggunakan SQLite (`sqflite`).
- Rekomendasi awal dari skor heuristik hasil pengukuran yang lengkap.
- Tidak membutuhkan server milik sendiri atau biaya Play Store.

## Kebutuhan
- Flutter stable SDK yang kompatibel dengan Dart 3.3+.
- Android Studio dan Android SDK.
- HP Android dan kabel USB (atau transfer APK).

## Menjalankan proyek
1. Ekstrak folder ZIP.
2. Buka terminal di folder `NetMonitor_Flutter`.
3. Jalankan:
   ```bash
   flutter create . --platforms=android
   flutter pub get
   flutter run
   ```
4. Jika `flutter create .` menanyakan penggantian file, pertahankan file `lib/main.dart`, `pubspec.yaml`, dan AndroidManifest dari paket ini. Periksa `applicationId` serta lokasi `MainActivity.kt` agar cocok dengan package `com.example.netmonitor`.
5. Di HP, aktifkan Developer options dan USB debugging, sambungkan ke laptop, lalu jalankan `flutter devices` dan `flutter run`.

## Build APK gratis
Dari terminal di folder proyek:
```bash
flutter build apk --release
```
Hasil biasanya berada di:
`build/app/outputs/flutter-apk/app-release.apk`

Salin APK ke HP dan buka file tersebut untuk menginstal. Android mungkin meminta izin "Install unknown apps" untuk aplikasi Files/browser yang digunakan.

## Catatan penting
- Paket sumber ini belum dikompilasi atau diuji pada perangkat nyata di lingkungan pembuatan ini. Jalankan `flutter pub get`, `flutter analyze`, dan `flutter build apk --release`; sesuaikan konfigurasi Gradle/Android jika template Flutter versi yang terpasang berbeda.
- `TCP connect latency` bukan ICMP ping murni.
- Speed test menggunakan endpoint publik; endpoint dapat dibatasi/berubah dan hasil dipengaruhi server, kondisi jaringan, dan perangkat. Gagal mengukur ditampilkan sebagai tidak tersedia, bukan nol.
- Android dapat membatasi SSID/RSSI bergantung izin, versi OS, dan kebijakan perangkat.
- Data tersimpan di SQLite lokal. Menghapus aplikasi dapat menghapus data lokal.
- Skor rekomendasi adalah heuristik awal untuk membandingkan lokasi, bukan jaminan kualitas Zoom. Untuk penelitian, ambil beberapa sampel per lokasi pada jam ramai dan sepi, lalu evaluasi rata-rata serta variasinya.
- Data IP lokal dan SSID bisa mengandung informasi jaringan pribadi; jangan mempublikasikan hasil mentah tanpa meninjau privasi.
