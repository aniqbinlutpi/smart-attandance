# Smart Attendance App (Flutter) 📱📍

Aplikasi mudah alih kehadiran pekerja menggunakan teknologi **Imbasan Wajah (Face Recognition)** dan **Geo-fencing**. Dibangunkan menggunakan Flutter untuk prestasi tinggi pada Android dan iOS.

![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.0%2B-blue?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey)

## 🌟 Fitur Utama

* **Imbasan Wajah (Face Recognition):** Menggunakan Google ML Kit / TensorFlow Lite untuk pengesahan identiti pekerja.
* **Geo-fencing (Radius Check):** Pekerja hanya boleh *check-in/out* jika berada dalam radius tertentu (contoh: 100m) dari pejabat.
* **Pengesanan Lokasi Palsu (Anti-Mock Location):** Menghalang penggunaan aplikasi "Fake GPS".
* **Liveness Detection:** Memastikan pengguna adalah manusia sebenar (bukan gambar statik) - *Work in Progress*.
* **Log Kehadiran:** Paparan sejarah check-in dan check-out.

## 🛠 Tech Stack

* **Framework:** Flutter (Dart)
* **State Management:** Provider / Bloc (Sila pilih satu)
* **Pakej Utama:**
    * `geolocator`: Untuk akses GPS dan kiraan jarak.
    * `google_mlkit_face_detection`: Untuk mengesan wajah dari kamera.
    * `camera`: Untuk akses hardware kamera.
    * `path_provider`: Pengurusan fail lokal.

## 🚀 Cara Mula (Getting Started)

Ikuti langkah ini untuk menjalankan projek di komputer anda.

### Prasyarat
Pastikan anda telah install:
1.  Flutter SDK (Latest Stable)
2.  Android Studio / VS Code
3.  Xcode (jika menggunakan macOS untuk iOS)

### Pemasangan

1.  **Clone repository ini:**
    ```bash
    git clone [https://github.com/username-anda/smart-attendance-flutter.git](https://github.com/username-anda/smart-attendance-flutter.git)
    cd smart-attendance-flutter
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Setup Permission (Wajib):**

    * **Android (`android/app/src/main/AndroidManifest.xml`):**
        ```xml
        <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
        <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
        <uses-permission android:name="android.permission.CAMERA" />
        ```

    * **iOS (`ios/Runner/Info.plist`):**
        ```xml
        <key>NSLocationWhenInUseUsageDescription</key>
        <string>Aplikasi memerlukan lokasi untuk mengesahkan kehadiran di pejabat.</string>
        <key>NSCameraUsageDescription</key>
        <string>Aplikasi memerlukan kamera untuk imbasan wajah.</string>
        ```

4.  **Run Aplikasi:**
    ```bash
    flutter run
    ```

## ⚙️ Konfigurasi Lokasi (Geo-fencing)

Untuk mengubah lokasi pejabat dan radius yang dibenarkan, sila edit fail `lib/constants.dart` (atau di mana anda simpan variable config):

```dart
// lib/constants.dart

class AppConstants {
  // Koordinat Pejabat (Contoh: Menara KLCC)
  static const double officeLat = 3.157764;
  static const double officeLng = 101.711864;

  // Radius dalam meter
  static const double allowedRadius = 100.0;
}