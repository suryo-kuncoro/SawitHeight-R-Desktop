# Pemetaan Tutorial ke Aplikasi

| Tahap tutorial | Implementasi pada SawitHeight R |
|---|---|
| 00 Persiapan Environment R | Deteksi `Rscript.exe`, pemeriksaan versi package, dan instalasi ke user library. |
| 01 Load Dense Point Cloud | Form input LAS/LAZ, pembacaan header untuk validasi, kemudian `readLAS()` saat run. |
| 02 Quality Check | Penghapusan duplikat, SOR noise, raster densitas, spacing, dan estimasi ukuran CHM. |
| 03 Klasifikasi Ground | CSF dengan cloth resolution, threshold, rigidness, slope smoothing, dan `last_returns = FALSE`. |
| 03B DTM Independen | Input GeoTIFF opsional, validasi CRS/cakupan, lalu normalisasi menggunakan raster DTM. |
| 04 Normalisasi TIN | `normalize_height(..., tin())`, validasi ground Z, dan normalized LAZ opsional. |
| 05 Generate nCHM | `rasterize_canopy(..., pitfree())`, resolusi otomatis/manual, GeoTIFF dan QC PNG. |
| 06 Zonal Statistics | Buffer bermeter, masking threshold kanopi, fractional coverage, statistik tinggi dan QC support. |
| 07 Klasifikasi & Export | Kelas tinggi, CSV, GeoPackage, Shapefile opsional, JSON, manifest, dan laporan HTML. |

## Perubahan yang disengaja

1. Backend tidak menggunakan `tidyverse`; operasi atribut sederhana memakai base R untuk
   mengurangi ukuran dan jumlah dependensi runtime.
2. `last_returns = FALSE` digunakan pada CSF karena dense cloud fotogrametri bukan data
   laser return.
3. Resolusi otomatis diberi batas minimum untuk mencegah raster sangat besar pada point
   cloud ultra-dense.
4. GeoPackage dijadikan output utama karena Shapefile membatasi panjang nama field.
5. Nilai di luar raster, dukungan piksel rendah, dan tutupan kanopi rendah diberi flag QC,
   bukan disembunyikan.
