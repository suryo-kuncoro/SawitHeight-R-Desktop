# SawitHeight R

Aplikasi desktop Windows untuk menjalankan analisis tinggi pohon sawit dari dense point
cloud fotogrametri dengan backend **R/lidR**. Ini bukan pembungkus tutorial: tombol
**Jalankan Analisis** mengeksekusi pipeline R, menampilkan progress dan log, menangani
error per tahap, lalu mengelola seluruh output dalam satu folder run.

## Fitur MVP

- Input LAS/LAZ, titik pokok SHP/GPKG/GeoJSON, dan DTM GeoTIFF opsional.
- Deteksi `Rscript.exe`, pemeriksaan package, dan instalasi package ke user library.
- Validasi ekstensi, geometri, CRS proyeksi, irisan extent, cakupan DTM, parameter,
  serta hak tulis folder output.
- QC duplikat dan Statistical Outlier Removal.
- Dua metode normalisasi:
  - CSF → TIN dari ground point.
  - DTM eksternal yang lebih disarankan untuk fotogrametri.
- Pembuatan normalized CHM dengan algoritma `pitfree`.
- Statistik buffer menggunakan fractional pixel coverage dari `exactextractr`.
- Progress dan log R real-time.
- Pembatalan proses.
- Output CSV, GeoPackage, GeoTIFF, QC PNG, JSON, manifest, dan laporan HTML.
- Konfigurasi build untuk Portable EXE dan installer per-user tanpa elevasi admin.

## Output setiap run

```text
run_YYYY-MM-DDT...
├── run_config.json
├── analysis.log
├── normalized_pointcloud.laz      # opsional
├── nCHM_sawit.tif
├── tinggi_pokok_sawit.csv
├── hasil_tinggi_pokok.gpkg
├── qc_density.png
├── qc_nchm.png
├── qc_histogram_height.png
├── output_manifest.csv
├── result_summary.json
└── report.html
```

## Menjalankan untuk pengembangan

Persyaratan:

- Windows 10/11 64-bit.
- Node.js 24 untuk proses build.
- R yang kompatibel beserta package: `jsonlite`, `lidR`, `terra`, `sf`,
  `exactextractr`, dan `RCSF`.

```powershell
npm install
npm start
```

Aplikasi dapat mendeteksi R pada lokasi umum. Jika tidak ditemukan, pilih
`Rscript.exe`, misalnya:

```text
C:\Program Files\R\R-4.x.x\bin\Rscript.exe
```

## Membuat EXE melalui GitHub Actions

1. Buat repository GitHub baru.
2. Unggah seluruh isi folder proyek.
3. Buka **Actions → Build Windows EXE → Run workflow**.
4. Pilih:
   - `bundle_r = false`: EXE lebih kecil, menggunakan R pada komputer pengguna.
   - `bundle_r = true`: membundel R dan package; ukuran jauh lebih besar tetapi runtime
     analisis dapat berjalan tanpa instalasi R terpisah.
5. Unduh artifact setelah workflow selesai.

Hasil build yang ditargetkan:

```text
SawitHeight-R-Portable-0.1.0.exe
SawitHeight-R-Setup-0.1.0.exe
```

## Catatan penting

- Build portable tidak memerlukan proses instalasi, tetapi kebijakan AppLocker/antivirus
  perusahaan tetap dapat membatasi executable.
- EXE yang belum ditandatangani sertifikat code-signing dapat memunculkan SmartScreen.
- Build self-contained berukuran besar karena membawa Electron, R, library geospasial,
  dan DLL dependensi.
- MVP memuat satu LAS/LAZ ke RAM. Untuk dataset sangat besar atau kumpulan tile,
  gunakan data yang sudah dipotong atau kembangkan mode LAScatalog.
- DTM eksternal harus menggunakan CRS proyeksi yang sama dan menutupi seluruh extent LAS.
- Parameter kelas tinggi 1,5 m dan 2,5 m adalah nilai awal dari tutorial, bukan standar
  biologis universal; sesuaikan dengan umur tanam dan hasil validasi lapangan.

## Status pengujian

Struktur Electron dan JavaScript telah diperiksa secara statis. Proyek belum dikompilasi menjadi EXE di lingkungan ini. Backend R juga harus diuji di Windows dengan data LAS/LAZ nyata karena lingkungan pembuat proyek ini tidak menyediakan runtime R maupun dataset point cloud uji. Versi yang dikunci untuk build awal adalah Electron 43.0.0 dan electron-builder 26.0.12.
