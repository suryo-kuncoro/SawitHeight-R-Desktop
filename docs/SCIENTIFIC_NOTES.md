# Catatan Ilmiah dan Operasional

- Dense cloud RGB merekonstruksi permukaan yang terlihat kamera dan tidak mempunyai
  penetrasi tajuk seperti LiDAR. Ground hasil CSF dapat jarang atau bias ketika gawangan
  tertutup.
- DTM independen sebelum tanam atau dari survei lain merupakan referensi tanah yang lebih
  kuat, tetapi wajib diperiksa kesesuaian datum, CRS, resolusi, waktu akuisisi, dan perubahan
  permukaan tanah.
- Statistik `tinggi_rerata` menggunakan rata-rata berbobot fractional coverage setelah
  piksel di bawah threshold kanopi diubah menjadi NoData. `tinggi_maks` tetap tersedia
  sebagai pembanding.
- Buffer 2 m, threshold 0,5 m, dan batas kelas 1,5/2,5 m adalah parameter awal. Kalibrasi
  wajib dilakukan terhadap umur tanaman, varietas, kondisi tajuk, ketelitian titik pokok,
  dan pengukuran tinggi lapangan.
- Flag QC:
  - `OK`: dukungan raster mencukupi.
  - `LOW_SUPPORT`: piksel kanopi kurang dari 10.
  - `LOW_CANOPY_COVER`: tutupan kanopi kurang dari 20% pada area raster yang tersedia.
  - `OUTSIDE_OR_NODATA`: buffer tidak mempunyai data CHM yang dapat digunakan.
- Nilai output sebaiknya dievaluasi dengan MAE, RMSE, bias, dan plot residual terhadap
  tinggi lapangan sebelum digunakan untuk keputusan operasional.
