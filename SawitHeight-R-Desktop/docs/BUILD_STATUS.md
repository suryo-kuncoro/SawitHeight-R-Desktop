# Status Build dan Validasi

## Sudah dilakukan

- Pemeriksaan sintaks JavaScript dengan `node --check`.
- Pemeriksaan struktur file wajib menggunakan `scripts/verify_project.js`.
- Parsing `package.json`, contoh konfigurasi JSON, dan workflow YAML.
- Audit jalur IPC, pemanggilan `Rscript`, event progress, pembatalan proses, dan pengelolaan run folder.
- Error backend terstruktur diteruskan ke UI.
- Kegagalan grafik QC dan Shapefile diperlakukan sebagai warning agar output utama tidak hilang.

## Belum dilakukan di lingkungan pembuatan

- `npm install` dan kompilasi Windows EXE.
- Eksekusi backend R.
- Uji integrasi dengan LAS/LAZ, titik pokok, dan DTM nyata.
- Benchmark RAM/waktu proses pada ukuran data produksi.
- Penandatanganan digital executable.

## Kriteria sebelum produksi

Gunakan dataset kecil yang telah memiliki tinggi lapangan, jalankan seluruh test pada `TEST_PLAN.md`, periksa CRS serta output QC, kemudian bandingkan estimasi dengan pengukuran lapangan sebelum menerapkan kelas tinggi secara operasional.
