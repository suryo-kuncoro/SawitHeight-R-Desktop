# Rencana Uji

## Uji environment

1. Rscript tidak ditemukan.
2. R ditemukan tetapi package hilang.
3. Instal package ke user library tanpa admin.
4. Bundled R terdeteksi pada build self-contained.

## Uji validasi data

1. LAS/LAZ tidak ada atau ekstensi salah.
2. CRS LAS kosong dengan dan tanpa EPSG fallback.
3. CRS geografis/derajat ditolak.
4. Titik bukan POINT/MULTIPOINT ditolak.
5. Titik tidak beririsan dengan LAS ditolak.
6. DTM beda CRS atau tidak mencakup seluruh LAS ditolak.
7. Folder output read-only ditolak.

## Uji pipeline

1. Run menggunakan CSF dan normalisasi TIN.
2. Run menggunakan DTM eksternal.
3. Ground kurang dari 3 titik menghasilkan error terarah.
4. Persentase ground di bawah 5% menghasilkan warning.
5. CHM NoData di atas 10% menghasilkan warning.
6. Pohon di luar raster diberi `OUTSIDE_OR_NODATA`.
7. Dukungan kanopi kurang dari 10 piksel diberi `LOW_SUPPORT`.
8. Pembatalan proses menutup Rscript dan mempertahankan log parsial.

## Uji output

- CSV dapat dibuka dan jumlah baris sama dengan titik input valid.
- GeoPackage mempunyai layer `tree_height` dan `tree_buffers`.
- GeoTIFF mempunyai CRS dan resolusi yang benar.
- Laporan HTML dan `result_summary.json` terbuka.
- Manifest hanya menandai file yang benar-benar ada.
