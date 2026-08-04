options(warn = 1, stringsAsFactors = FALSE)

args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args) >= 1) args[[1]] else ''
config_path <- if (length(args) >= 2) args[[2]] else ''

base_event <- function(type, message, level = 'error') {
  fields <- c(
    paste0('\"type\":', encodeString(as.character(type), quote = '"')),
    paste0('\"level\":', encodeString(as.character(level), quote = '"')),
    paste0('\"message\":', encodeString(as.character(message), quote = '"'))
  )
  cat('APP_EVENT:{', paste(fields, collapse = ','), '}\n', sep = '')
  flush.console()
}

if (!mode %in% c('validate', 'run') || !nzchar(config_path) || !file.exists(config_path)) {
  base_event('fatal', 'Argumen backend tidak valid atau file konfigurasi tidak ditemukan.')
  quit(status = 2)
}

if (!requireNamespace('jsonlite', quietly = TRUE)) {
  base_event('fatal', 'Package jsonlite belum terpasang. Jalankan pemeriksaan environment dan instal package.')
  quit(status = 3)
}

required_packages <- c('lidR', 'terra', 'sf', 'exactextractr', 'RCSF')
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  base_event('fatal', paste('Package R belum tersedia:', paste(missing_packages, collapse = ', ')))
  quit(status = 4)
}

suppressPackageStartupMessages({
  library(lidR)
  library(terra)
  library(sf)
  library(exactextractr)
})

options(lidR.raster.default = 'terra')

cfg <- jsonlite::fromJSON(config_path, simplifyVector = TRUE)
inputs <- cfg$inputs
p <- cfg$parameters
run_dir <- normalizePath(cfg$app$run_dir, winslash = '/', mustWork = FALSE)
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
log_path <- file.path(run_dir, if (mode == 'run') 'analysis.log' else 'validation.log')
current_stage <- 'initialization'

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || is.na(x) || identical(x, '')) y else x

emit <- function(type, ..., .level = NULL) {
  payload <- list(type = type, timestamp = format(Sys.time(), '%Y-%m-%dT%H:%M:%S%z'))
  dots <- list(...)
  payload <- c(payload, dots)
  if (!is.null(.level)) payload$level <- .level
  text <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = 'null', na = 'null', digits = 10)
  cat('APP_EVENT:', text, '\n', sep = '')
  flush.console()
}

write_log <- function(level, message) {
  line <- sprintf('[%s] [%s] [%s] %s', format(Sys.time(), '%Y-%m-%d %H:%M:%S'), level, current_stage, message)
  cat(line, '\n', file = log_path, append = TRUE)
  emit('log', level = tolower(level), stage = current_stage, message = message)
}

set_stage <- function(id, label, progress) {
  current_stage <<- id
  emit('progress', stage = id, label = label, progress = progress)
  cat(sprintf('[%s] [STAGE] [%s] %s\n', format(Sys.time(), '%Y-%m-%d %H:%M:%S'), id, label),
      file = log_path, append = TRUE)
}

stop_app <- function(message) stop(message, call. = FALSE)

as_num <- function(x, default = NA_real_) {
  value <- suppressWarnings(as.numeric(x))
  if (!length(value) || is.na(value)) default else value
}

as_int <- function(x, default = NA_integer_) {
  value <- suppressWarnings(as.integer(x))
  if (!length(value) || is.na(value)) default else value
}

as_bool <- function(x, default = FALSE) {
  if (is.null(x) || !length(x) || is.na(x)) default else isTRUE(x)
}

ensure_writable_dir <- function(path_value) {
  dir.create(path_value, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path_value)) stop_app(paste('Folder output tidak dapat dibuat:', path_value))
  test_file <- file.path(path_value, paste0('.write_test_', Sys.getpid()))
  ok <- tryCatch({
    writeLines('test', test_file)
    unlink(test_file)
    TRUE
  }, error = function(e) FALSE)
  if (!ok) stop_app(paste('Folder output tidak dapat ditulis:', path_value))
}

check_extension <- function(path_value, allowed, label) {
  ext <- tolower(tools::file_ext(path_value))
  if (!ext %in% allowed) stop_app(paste(label, 'harus berformat', paste(paste0('.', allowed), collapse = ', ')))
}

get_las_crs <- function(obj, fallback_epsg = 0L) {
  crs_obj <- suppressWarnings(sf::st_crs(obj))
  if (is.na(crs_obj) && fallback_epsg > 0L) {
    crs_obj <- sf::st_crs(fallback_epsg)
    try(suppressWarnings(sf::st_crs(obj) <- crs_obj), silent = TRUE)
  }
  list(object = obj, crs = crs_obj)
}

validate_vector_points <- function(points) {
  if (!inherits(points, 'sf')) stop_app('Data titik pokok gagal dibaca sebagai objek sf.')
  if (!nrow(points)) stop_app('Data titik pokok tidak memiliki fitur.')
  geom_types <- unique(as.character(sf::st_geometry_type(points, by_geometry = TRUE)))
  if (!all(geom_types %in% c('POINT', 'MULTIPOINT'))) {
    stop_app(paste('Geometri titik pokok harus POINT/MULTIPOINT, ditemukan:', paste(geom_types, collapse = ', ')))
  }
  if (any(geom_types == 'MULTIPOINT')) points <- suppressWarnings(sf::st_cast(points, 'POINT'))
  if (any(sf::st_is_empty(points))) {
    write_log('WARNING', 'Terdapat geometri titik kosong; fitur kosong akan dihapus.')
    points <- points[!sf::st_is_empty(points), , drop = FALSE]
  }
  if (!nrow(points)) stop_app('Tidak ada titik valid setelah geometri kosong dihapus.')
  points
}

crs_equal <- function(a, b) {
  if (is.na(a) || is.na(b)) return(FALSE)
  isTRUE(a == b)
}

extent_contains_bbox <- function(raster_obj, bbox_obj, tolerance = 0) {
  as.numeric(terra::xmin(raster_obj)) <= as.numeric(bbox_obj['xmin']) + tolerance &&
    as.numeric(terra::xmax(raster_obj)) >= as.numeric(bbox_obj['xmax']) - tolerance &&
    as.numeric(terra::ymin(raster_obj)) <= as.numeric(bbox_obj['ymin']) + tolerance &&
    as.numeric(terra::ymax(raster_obj)) >= as.numeric(bbox_obj['ymax']) - tolerance
}

safe_png <- function(filename, width = 1400, height = 900, expr) {
  grDevices::png(filename, width = width, height = height, res = 130)
  on.exit(grDevices::dev.off(), add = TRUE)
  force(expr)
}

try_qc_png <- function(filename, label, expr) {
  tryCatch(
    safe_png(filename, expr = expr),
    error = function(e) {
      write_log('WARNING', paste('Gagal membuat', label, ':', conditionMessage(e)))
      if (file.exists(filename)) unlink(filename)
      invisible(FALSE)
    }
  )
}

make_html_report <- function(summary, preview, output_path) {
  esc <- function(x) {
    x <- gsub('&', '&amp;', as.character(x), fixed = TRUE)
    x <- gsub('<', '&lt;', x, fixed = TRUE)
    x <- gsub('>', '&gt;', x, fixed = TRUE)
    x
  }
  cards <- paste0(
    '<div class="card"><b>Jumlah titik input</b><span>', format(summary$input_points, big.mark = '.'), '</span></div>',
    '<div class="card"><b>Densitas rata-rata</b><span>', round(summary$avg_density_points_m2, 2), ' titik/m²</span></div>',
    '<div class="card"><b>Resolusi CHM</b><span>', summary$chm_resolution_m, ' m</span></div>',
    '<div class="card"><b>Titik pokok</b><span>', summary$tree_count, '</span></div>',
    '<div class="card"><b>Hasil valid</b><span>', summary$valid_height_count, '</span></div>',
    '<div class="card"><b>Run</b><span>', esc(summary$run_name), '</span></div>'
  )
  rows <- apply(preview, 1, function(row) {
    paste0('<tr>', paste0('<td>', esc(row), '</td>', collapse = ''), '</tr>')
  })
  table_html <- paste0('<table><thead><tr>', paste0('<th>', esc(names(preview)), '</th>', collapse = ''),
                       '</tr></thead><tbody>', paste(rows, collapse = ''), '</tbody></table>')
  html <- paste0('<!doctype html><html><head><meta charset="utf-8"><title>SawitHeight R Report</title>',
    '<style>body{font-family:Arial,sans-serif;background:#0b0f11;color:#e7edee;padding:32px}',
    'h1{margin-bottom:6px}.sub{color:#91a1a5}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:24px 0}',
    '.card{background:#151d20;border:1px solid #2b393d;padding:16px;border-radius:10px;display:flex;flex-direction:column;gap:8px}',
    '.card b{color:#91a1a5;font-size:12px}.card span{font-size:20px;color:#e3a73f}',
    'table{border-collapse:collapse;width:100%;background:#12181b}th,td{border:1px solid #2b393d;padding:8px;font-size:12px;text-align:left}',
    'th{background:#1a2326;color:#e3a73f}</style></head><body>',
    '<h1>SawitHeight R — Ringkasan Analisis</h1><div class="sub">Estimasi tinggi pohon sawit dari dense point cloud fotogrametri</div>',
    '<div class="grid">', cards, '</div><h2>Pratinjau Hasil</h2>', table_html,
    '<p class="sub">Lihat run_config.json dan analysis.log untuk audit parameter dan proses.</p></body></html>')
  writeLines(html, output_path, useBytes = TRUE)
}

validate_common <- function(load_full_las = FALSE) {
  set_stage('validation', 'Memvalidasi file, CRS, dan parameter', 5)
  point_cloud <- normalizePath(inputs$point_cloud, winslash = '/', mustWork = TRUE)
  tree_points_path <- normalizePath(inputs$tree_points, winslash = '/', mustWork = TRUE)
  output_root <- normalizePath(inputs$output_root, winslash = '/', mustWork = FALSE)
  check_extension(point_cloud, c('las', 'laz'), 'Point cloud')
  check_extension(tree_points_path, c('shp', 'gpkg', 'geojson', 'json'), 'Titik pokok')
  ensure_writable_dir(output_root)

  fallback_epsg <- as_int(p$fallback_epsg, 0L)
  header <- lidR::readLASheader(point_cloud)
  if (is.null(header)) stop_app('Header LAS/LAZ tidak dapat dibaca.')
  las_crs_info <- get_las_crs(header, fallback_epsg)
  header <- las_crs_info$object
  las_crs <- las_crs_info$crs
  if (is.na(las_crs)) stop_app('CRS point cloud kosong. Isi EPSG fallback yang sesuai.')
  if (isTRUE(sf::st_is_longlat(las_crs))) stop_app('CRS point cloud masih geografis/derajat. Gunakan CRS proyeksi bermeter untuk buffer dan tinggi.')
  crs_units <- tolower(as.character(las_crs$units_gdal %||% ''))
  if (nzchar(crs_units) && !crs_units %in% c('metre', 'meter', 'metres', 'meters', 'm')) {
    stop_app(paste('Satuan horizontal CRS bukan meter:', crs_units, '. Parameter buffer, CSF, dan resolusi aplikasi menggunakan meter.'))
  }
  if (!nzchar(crs_units)) write_log('WARNING', 'Satuan horizontal CRS tidak teridentifikasi; aplikasi mengasumsikan meter.')

  points <- suppressWarnings(sf::st_read(tree_points_path, quiet = TRUE))
  points <- validate_vector_points(points)
  if (is.na(sf::st_crs(points))) {
    write_log('WARNING', 'CRS titik pokok kosong; CRS point cloud diterapkan sebagai asumsi.')
    sf::st_crs(points) <- las_crs
  }
  points <- sf::st_transform(points, las_crs)
  requested_id <- as.character(p$tree_id_field %||% '')
  if (nzchar(requested_id) && !requested_id %in% names(points)) {
    stop_app(paste('Field ID pohon tidak ditemukan pada data titik:', requested_id))
  }

  las_bbox <- sf::st_bbox(header)
  points_bbox <- sf::st_bbox(points)
  intersects_bbox <- !(points_bbox['xmax'] < las_bbox['xmin'] || points_bbox['xmin'] > las_bbox['xmax'] ||
                       points_bbox['ymax'] < las_bbox['ymin'] || points_bbox['ymin'] > las_bbox['ymax'])
  if (!intersects_bbox) stop_app('Extent titik pokok tidak beririsan dengan extent point cloud.')

  dtm <- NULL
  if (as_bool(p$use_external_dtm)) {
    dtm_path <- normalizePath(inputs$external_dtm, winslash = '/', mustWork = TRUE)
    check_extension(dtm_path, c('tif', 'tiff'), 'DTM eksternal')
    dtm <- terra::rast(dtm_path)
    if (terra::nlyr(dtm) != 1) stop_app('DTM eksternal harus mempunyai tepat satu band elevasi.')
    dtm_crs <- sf::st_crs(terra::crs(dtm, proj = TRUE))
    if (is.na(dtm_crs)) stop_app('CRS DTM eksternal kosong.')
    if (!crs_equal(dtm_crs, las_crs)) stop_app('CRS DTM eksternal berbeda dari CRS point cloud. Reproject DTM terlebih dahulu agar resolusi dan grid tetap terkontrol.')
    if (!extent_contains_bbox(dtm, las_bbox)) stop_app('DTM eksternal tidak menutupi seluruh extent point cloud.')
  }

  parameter_checks <- c(
    buffer_m = as_num(p$buffer_m),
    canopy_threshold_m = as_num(p$canopy_threshold_m),
    sor_k = as_num(p$sor_k),
    sor_m = as_num(p$sor_m),
    csf_cloth_resolution = as_num(p$csf_cloth_resolution),
    csf_class_threshold = as_num(p$csf_class_threshold),
    chm_resolution = as_num(p$chm_resolution),
    chm_min_auto_resolution = as_num(p$chm_min_auto_resolution),
    threads = as_num(p$threads)
  )
  invalid <- names(parameter_checks)[!is.finite(parameter_checks) | parameter_checks <= 0]
  if (length(invalid)) stop_app(paste('Parameter harus lebih besar dari 0:', paste(invalid, collapse = ', ')))
  if (as_num(p$height_break_1_m) < 0 || as_num(p$height_break_2_m) < 0) stop_app('Batas kelas tinggi tidak boleh negatif.')
  if (as_num(p$height_break_1_m) >= as_num(p$height_break_2_m)) stop_app('Batas kelas tinggi pertama harus lebih kecil dari batas kedua.')
  rigidness <- as_int(p$csf_rigidness)
  if (!rigidness %in% 1:3) stop_app('CSF rigidness hanya boleh 1, 2, atau 3.')

  emit('validation-result', status = 'valid', point_cloud = point_cloud,
       tree_count = nrow(points), crs = las_crs$input %||% las_crs$wkt,
       use_external_dtm = as_bool(p$use_external_dtm))

  list(point_cloud = point_cloud, points_path = tree_points_path, output_root = output_root,
       header = header, las_crs = las_crs, points = points, dtm = dtm)
}

run_pipeline <- function() {
  validated <- validate_common(TRUE)
  lidR::set_lidr_threads(as_int(p$threads, 1L))
  write_log('INFO', paste('R:', R.version.string))
  write_log('INFO', paste('lidR:', as.character(utils::packageVersion('lidR'))))
  write_log('INFO', paste('Point cloud:', validated$point_cloud))

  set_stage('load', 'Memuat dense point cloud', 10)
  las <- lidR::readLAS(validated$point_cloud)
  if (is.null(las) || lidR::is.empty(las)) stop_app('Point cloud kosong atau gagal dimuat.')
  las_crs_info <- get_las_crs(las, as_int(p$fallback_epsg, 0L))
  las <- las_crs_info$object
  input_points <- lidR::npoints(las)
  write_log('INFO', paste('Jumlah titik input:', format(input_points, big.mark = ',')))

  set_stage('clean', 'Membersihkan duplikat dan noise', 20)
  before_clean <- lidR::npoints(las)
  if (as_bool(p$remove_duplicates, TRUE)) {
    las <- lidR::filter_duplicates(las)
    write_log('INFO', paste('Duplikat XYZ dihapus:', before_clean - lidR::npoints(las)))
  }
  if (as_bool(p$remove_noise, TRUE)) {
    las <- lidR::classify_noise(las, lidR::sor(k = as_int(p$sor_k, 10L), m = as_num(p$sor_m, 3)))
    noise_count <- sum(las$Classification == lidR::LASNOISE, na.rm = TRUE)
    las <- lidR::remove_noise(las)
    write_log('INFO', paste('Noise SOR dihapus:', noise_count))
  }
  if (lidR::is.empty(las)) stop_app('Semua titik terhapus pada tahap pembersihan.')

  set_stage('density', 'Menghitung densitas dan resolusi CHM', 28)
  density_raster <- lidR::rasterize_density(las, res = 1)
  avg_density <- as.numeric(terra::global(density_raster, 'mean', na.rm = TRUE)[1, 1])
  if (!is.finite(avg_density) || avg_density <= 0) stop_app('Densitas point cloud tidak dapat dihitung.')
  avg_spacing <- 1 / sqrt(avg_density)
  auto_res <- max(as_num(p$chm_min_auto_resolution, 0.05), round(avg_spacing * 2, 2))
  chm_res <- if (as_bool(p$chm_auto_resolution, TRUE)) auto_res else as_num(p$chm_resolution, 0.1)
  las_bbox_for_grid <- sf::st_bbox(las)
  estimated_cells <- ceiling((as.numeric(las_bbox_for_grid['xmax']) - as.numeric(las_bbox_for_grid['xmin'])) / chm_res) *
    ceiling((as.numeric(las_bbox_for_grid['ymax']) - as.numeric(las_bbox_for_grid['ymin'])) / chm_res)
  if (estimated_cells > 250000000) {
    stop_app(sprintf('Estimasi raster CHM mencapai %.1f juta piksel. Naikkan resolusi CHM atau potong point cloud agar risiko kehabisan RAM berkurang.', estimated_cells / 1e6))
  }
  if (estimated_cells > 100000000) {
    write_log('WARNING', sprintf('Estimasi raster CHM besar: %.1f juta piksel.', estimated_cells / 1e6))
  }
  write_log('INFO', sprintf('Densitas rata-rata %.3f titik/m2; spacing %.4f m; resolusi CHM %.3f m; estimasi %.1f juta piksel', avg_density, avg_spacing, chm_res, estimated_cells / 1e6))
  density_png <- file.path(run_dir, 'qc_density.png')
  try_qc_png(density_png, 'grafik densitas', terra::plot(density_raster, main = 'Densitas Point Cloud (titik/m2)'))

  set_stage('ground', if (as_bool(p$use_external_dtm)) 'Memuat DTM eksternal' else 'Mengklasifikasikan ground dengan CSF', 38)
  ground_pct <- NA_real_
  if (as_bool(p$use_external_dtm)) {
    dtm <- validated$dtm
    write_log('INFO', 'Normalisasi akan menggunakan DTM eksternal.')
  } else {
    algorithm <- lidR::csf(
      sloop_smooth = as_bool(p$csf_slope_smooth, FALSE),
      class_threshold = as_num(p$csf_class_threshold, 0.3),
      cloth_resolution = as_num(p$csf_cloth_resolution, 0.5),
      rigidness = as_int(p$csf_rigidness, 2L)
    )
    las <- lidR::classify_ground(las, algorithm, last_returns = FALSE)
    ground_count <- sum(las$Classification == lidR::LASGROUND, na.rm = TRUE)
    ground_pct <- ground_count / lidR::npoints(las) * 100
    write_log('INFO', sprintf('Ground terklasifikasi: %s titik (%.2f%%)', format(ground_count, big.mark = ','), ground_pct))
    if (ground_count < 3) stop_app('Ground point kurang dari 3; normalisasi TIN tidak dapat dilakukan. Gunakan DTM eksternal atau ubah parameter CSF.')
    if (ground_pct < 5) write_log('WARNING', 'Persentase ground di bawah 5%. Hasil normalisasi dari fotogrametri berpotensi tidak stabil; DTM eksternal lebih disarankan.')
  }

  set_stage('normalize', 'Menormalisasi tinggi point cloud', 50)
  if (as_bool(p$use_external_dtm)) {
    nlas <- lidR::normalize_height(las, validated$dtm)
  } else {
    nlas <- lidR::normalize_height(las, lidR::tin())
  }
  nlas <- lidR::filter_poi(nlas, is.finite(Z) & Z >= -0.1)
  if (lidR::is.empty(nlas)) stop_app('Point cloud ternormalisasi kosong.')
  normalized_points <- lidR::npoints(nlas)
  if (!as_bool(p$use_external_dtm)) {
    gnd <- lidR::filter_ground(nlas)
    if (!lidR::is.empty(gnd)) {
      write_log('INFO', sprintf('Ground Z setelah normalisasi: min %.4f; mean %.4f; max %.4f', min(gnd$Z), mean(gnd$Z), max(gnd$Z)))
    }
  }
  normalized_laz <- ''
  if (as_bool(p$save_normalized_laz, TRUE)) {
    normalized_laz <- file.path(run_dir, 'normalized_pointcloud.laz')
    lidR::writeLAS(nlas, normalized_laz)
  }

  set_stage('chm', 'Membuat normalized Canopy Height Model', 62)
  chm <- lidR::rasterize_canopy(
    nlas,
    res = chm_res,
    algorithm = lidR::pitfree(thresholds = c(0, 2, 5, 10), max_edge = c(0, 1.5))
  )
  if (!inherits(chm, 'SpatRaster')) chm <- terra::rast(chm)
  chm_path <- file.path(run_dir, 'nCHM_sawit.tif')
  terra::writeRaster(chm, chm_path, overwrite = TRUE, wopt = list(gdal = c('COMPRESS=LZW', 'TILED=YES')))
  na_cells <- as.numeric(terra::global(is.na(chm), 'sum', na.rm = TRUE)[1, 1])
  na_pct <- na_cells / terra::ncell(chm) * 100
  write_log('INFO', sprintf('CHM: resolusi %.3f m; piksel NA %.2f%%', chm_res, na_pct))
  if (na_pct > 10) write_log('WARNING', 'Piksel NA CHM lebih dari 10%. Pertimbangkan resolusi CHM lebih kasar.')
  chm_png <- file.path(run_dir, 'qc_nchm.png')
  try_qc_png(chm_png, 'pratinjau nCHM', terra::plot(chm, main = 'Normalized Canopy Height Model (m)'))
  histogram_png <- file.path(run_dir, 'qc_histogram_height.png')
  try_qc_png(histogram_png, 'histogram tinggi', terra::hist(chm, breaks = 60, main = 'Distribusi Nilai nCHM', xlab = 'Tinggi (m)'))

  set_stage('zonal', 'Menghitung statistik tinggi pada buffer titik pokok', 75)
  points <- validated$points
  points <- sf::st_transform(points, sf::st_crs(terra::crs(chm, proj = TRUE)))
  id_field <- as.character(p$tree_id_field %||% '')
  if (nzchar(id_field)) {
    if (!id_field %in% names(points)) stop_app(paste('Field ID tidak ditemukan:', id_field))
    if (anyDuplicated(points[[id_field]])) write_log('WARNING', paste('Field ID tidak unik:', id_field))
  } else {
    id_field <- 'tree_id'
    while (id_field %in% names(points)) id_field <- paste0(id_field, '_x')
    points[[id_field]] <- seq_len(nrow(points))
  }

  buffer_m <- as_num(p$buffer_m, 2)
  buffers <- sf::st_buffer(points, dist = buffer_m)
  threshold <- as_num(p$canopy_threshold_m, 0.5)
  chm_masked <- terra::ifel(chm >= threshold, chm, NA)

  stat_fun <- function(values, coverage_fraction) {
    values <- as.numeric(values)
    coverage_fraction <- as.numeric(coverage_fraction)
    ok <- is.finite(values) & is.finite(coverage_fraction) & coverage_fraction > 0
    if (!any(ok)) {
      return(data.frame(
        tinggi_rerata = NA_real_, tinggi_maks = NA_real_, tinggi_min = NA_real_,
        tinggi_sd = NA_real_, n_piksel_kanopi = 0L, bobot_piksel_kanopi = 0
      ))
    }
    v <- values[ok]
    w <- coverage_fraction[ok]
    data.frame(
      tinggi_rerata = sum(v * w) / sum(w),
      tinggi_maks = max(v),
      tinggi_min = min(v),
      tinggi_sd = if (length(v) > 1) stats::sd(v) else 0,
      n_piksel_kanopi = length(v),
      bobot_piksel_kanopi = sum(w)
    )
  }

  height_stats <- exactextractr::exact_extract(
    chm_masked, buffers, fun = stat_fun,
    summarize_df = FALSE, progress = FALSE
  )
  observed_binary <- terra::ifel(is.na(chm), NA, terra::ifel(chm >= threshold, 1, 0))
  canopy_fraction <- exactextractr::exact_extract(observed_binary, buffers, fun = 'mean', progress = FALSE)
  available_pixels <- exactextractr::exact_extract(chm, buffers, fun = 'count', progress = FALSE)

  points$tinggi_rerata <- height_stats$tinggi_rerata
  points$tinggi_maks <- height_stats$tinggi_maks
  points$tinggi_min <- height_stats$tinggi_min
  points$tinggi_sd <- height_stats$tinggi_sd
  points$n_piksel_kanopi <- as.integer(height_stats$n_piksel_kanopi)
  points$bobot_piksel_kanopi <- height_stats$bobot_piksel_kanopi
  points$pct_tutupan_kanopi <- round(as.numeric(canopy_fraction) * 100, 2)
  points$n_piksel_tersedia <- as.numeric(available_pixels)

  break1 <- as_num(p$height_break_1_m, 1.5)
  break2 <- as_num(p$height_break_2_m, 2.5)
  points$kelas_tinggi <- ifelse(
    is.na(points$tinggi_rerata), 'Tidak tersedia',
    ifelse(points$tinggi_rerata < break1, 'Pendek (terhambat)',
      ifelse(points$tinggi_rerata < break2, 'Sedang (normal)', 'Tinggi (subur)'))
  )
  points$status_qc <- ifelse(
    is.na(points$tinggi_rerata) | points$n_piksel_tersedia <= 0, 'OUTSIDE_OR_NODATA',
    ifelse(points$n_piksel_kanopi < 10, 'LOW_SUPPORT',
      ifelse(points$pct_tutupan_kanopi < 20, 'LOW_CANOPY_COVER', 'OK'))
  )

  buffers_out <- buffers
  buffers_out[[id_field]] <- points[[id_field]]
  buffers_out$tinggi_rerata <- points$tinggi_rerata
  buffers_out$status_qc <- points$status_qc

  set_stage('export', 'Mengekspor CSV, GeoPackage, raster, dan laporan', 88)
  csv_path <- file.path(run_dir, 'tinggi_pokok_sawit.csv')
  utils::write.csv(sf::st_drop_geometry(points), csv_path, row.names = FALSE, na = '')

  gpkg_path <- file.path(run_dir, 'hasil_tinggi_pokok.gpkg')
  if (file.exists(gpkg_path)) unlink(gpkg_path)
  sf::st_write(points, gpkg_path, layer = 'tree_height', quiet = TRUE)
  sf::st_write(buffers_out, gpkg_path, layer = 'tree_buffers', append = TRUE, quiet = TRUE)

  shapefile_paths <- character(0)
  if (as_bool(p$export_shapefile, FALSE)) {
    shp_dir <- file.path(run_dir, 'shapefile')
    dir.create(shp_dir, showWarnings = FALSE)
    point_shp <- file.path(shp_dir, 'pokok_sawit_tinggi.shp')
    buffer_shp <- file.path(shp_dir, 'buffer_pokok.shp')
    tryCatch({
      suppressWarnings(sf::st_write(points, point_shp, delete_layer = TRUE, quiet = TRUE))
      suppressWarnings(sf::st_write(buffers_out, buffer_shp, delete_layer = TRUE, quiet = TRUE))
      shapefile_paths <- c(point_shp, buffer_shp)
      write_log('WARNING', 'Ekspor Shapefile dapat memotong nama field menjadi 10 karakter; GeoPackage adalah output utama.')
    }, error = function(e) {
      write_log('WARNING', paste('Ekspor Shapefile gagal, tetapi output utama GeoPackage tetap tersedia:', conditionMessage(e)))
    })
  }

  preview_cols <- unique(c(id_field, 'tinggi_rerata', 'tinggi_maks', 'pct_tutupan_kanopi', 'kelas_tinggi', 'status_qc'))
  preview <- head(sf::st_drop_geometry(points)[, preview_cols, drop = FALSE], 20)
  valid_height_count <- sum(is.finite(points$tinggi_rerata))
  class_table <- as.list(table(points$kelas_tinggi, useNA = 'ifany'))
  qc_table <- as.list(table(points$status_qc, useNA = 'ifany'))

  outputs <- c(
    config_path, log_path, chm_path, csv_path, gpkg_path, density_png, chm_png, histogram_png,
    if (nzchar(normalized_laz)) normalized_laz else character(0), shapefile_paths
  )
  outputs <- unique(outputs[file.exists(outputs)])
  manifest <- data.frame(
    file = basename(outputs),
    path = normalizePath(outputs, winslash = '/', mustWork = FALSE),
    exists = file.exists(outputs),
    size_mb = round(ifelse(file.exists(outputs), file.info(outputs)$size / 1024^2, NA_real_), 3)
  )
  manifest_path <- file.path(run_dir, 'output_manifest.csv')
  utils::write.csv(manifest, manifest_path, row.names = FALSE)

  summary <- list(
    status = 'success',
    run_name = basename(run_dir),
    run_dir = run_dir,
    input_points = input_points,
    normalized_points = normalized_points,
    avg_density_points_m2 = avg_density,
    avg_spacing_m = avg_spacing,
    chm_resolution_m = chm_res,
    chm_na_pct = na_pct,
    ground_pct = ground_pct,
    tree_count = nrow(points),
    valid_height_count = valid_height_count,
    class_counts = class_table,
    qc_counts = qc_table,
    output_files = c(outputs, manifest_path),
    preview = preview
  )
  result_json <- file.path(run_dir, 'result_summary.json')
  jsonlite::write_json(summary, result_json, pretty = TRUE, auto_unbox = TRUE, na = 'null')
  report_path <- file.path(run_dir, 'report.html')
  make_html_report(summary, preview, report_path)
  summary$output_files <- c(summary$output_files, result_json, report_path)
  jsonlite::write_json(summary, result_json, pretty = TRUE, auto_unbox = TRUE, na = 'null')

  set_stage('complete', 'Analisis selesai', 100)
  emit('result', status = 'success', runDir = run_dir, summaryPath = result_json,
       reportPath = report_path, summary = summary)
  write_log('INFO', 'Analisis selesai tanpa fatal error.')
}

status <- 0L
withCallingHandlers(
  tryCatch({
    if (mode == 'validate') {
      validate_common(FALSE)
      set_stage('complete', 'Validasi berhasil', 100)
      emit('validation-result', status = 'success', message = 'Semua input utama valid untuk diproses.')
    } else {
      run_pipeline()
    }
  }, error = function(e) {
    status <<- 10L
    message <- conditionMessage(e)
    try(cat(sprintf('[%s] [FATAL] [%s] %s\n', format(Sys.time(), '%Y-%m-%d %H:%M:%S'), current_stage, message),
            file = log_path, append = TRUE), silent = TRUE)
    emit('fatal', stage = current_stage, message = message, runDir = run_dir, logPath = log_path)
  }),
  warning = function(w) {
    message <- conditionMessage(w)
    try(write_log('WARNING', message), silent = TRUE)
    invokeRestart('muffleWarning')
  }
)
quit(status = status)
