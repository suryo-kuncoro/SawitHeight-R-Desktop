# Arsitektur SawitHeight R

```text
Renderer UI (HTML/CSS/JavaScript)
          │ API terbatas via contextBridge
          ▼
Electron Main Process
  - dialog file/folder
  - deteksi Rscript
  - validasi path dasar
  - spawn Rscript tanpa shell
  - streaming stdout/stderr
          │ APP_EVENT:{JSON}
          ▼
Backend R
  - lidR
  - terra
  - sf
  - exactextractr
  - RCSF
          │
          ▼
Folder run bertimestamp
  - run_config.json
  - analysis.log
  - normalized_pointcloud.laz (opsional)
  - nCHM_sawit.tif
  - tinggi_pokok_sawit.csv
  - hasil_tinggi_pokok.gpkg
  - QC PNG
  - report.html
  - result_summary.json
```

## Keamanan

Renderer tidak memperoleh akses langsung ke Node.js. `nodeIntegration` dinonaktifkan,
`contextIsolation` dan sandbox diaktifkan. Semua akses file dan proses dilakukan melalui
API preload yang terbatas. Rscript dijalankan dengan `spawn()` tanpa shell, sehingga path
pengguna tidak dieksekusi sebagai perintah shell.

## Batas MVP

- Satu file LAS/LAZ per run dan dimuat ke RAM.
- DTM eksternal tidak direproject otomatis; harus sama CRS dan menutupi seluruh point cloud.
- Klasifikasi ground menggunakan CSF dengan `last_returns = FALSE`, sesuai karakter dense
  cloud fotogrametri yang tidak memiliki return laser bermakna.
- Dukungan LAScatalog/tile processing direncanakan untuk versi berikutnya.
