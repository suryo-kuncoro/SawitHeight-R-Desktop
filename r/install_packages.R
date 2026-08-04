options(warn = 1)

json_string <- function(x) encodeString(as.character(x), quote = '"')

emit <- function(type, message, level = 'info', progress = NULL) {
  fields <- c(
    paste0('\"type\":', json_string(type)),
    paste0('\"level\":', json_string(level)),
    paste0('\"message\":', json_string(message))
  )
  if (!is.null(progress)) fields <- c(fields, paste0('\"progress\":', as.numeric(progress)))
  cat('APP_EVENT:{', paste(fields, collapse = ','), '}\n', sep = '')
  flush.console()
}

required <- c('jsonlite', 'lidR', 'terra', 'sf', 'exactextractr', 'RCSF')
minor <- paste(R.version$major, strsplit(R.version$minor, '\\.')[[1]][1], sep = '.')
local_appdata <- Sys.getenv('LOCALAPPDATA', unset = '')
user_lib <- Sys.getenv('R_LIBS_USER', unset = '')

if (!nzchar(user_lib) || grepl('%', user_lib, fixed = TRUE)) {
  if (nzchar(local_appdata)) {
    user_lib <- file.path(local_appdata, 'R', 'win-library', minor)
  } else {
    user_lib <- file.path(path.expand('~'), 'R', 'win-library', minor)
  }
}

dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(user_lib)) {
  emit('fatal', paste('Tidak dapat membuat user library:', user_lib), 'error')
  quit(status = 2)
}
.libPaths(c(user_lib, .libPaths()))
emit('log', paste('User library:', user_lib))

missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (!length(missing)) {
  emit('package-install', 'Semua package R sudah tersedia.', 'success', 100)
  quit(status = 0)
}

emit('package-install', paste('Package yang akan dipasang:', paste(missing, collapse = ', ')), 'info', 5)

ok <- TRUE
for (i in seq_along(missing)) {
  pkg <- missing[i]
  pct <- 5 + round((i - 1) / length(missing) * 85)
  emit('package-install', paste('Menginstal', pkg, 'beserta dependensi...'), 'info', pct)
  tryCatch({
    utils::install.packages(
      pkg,
      lib = user_lib,
      repos = 'https://cloud.r-project.org',
      dependencies = TRUE,
      type = .Platform$pkgType
    )
  }, error = function(e) {
    ok <<- FALSE
    emit('log', paste('Gagal menginstal', pkg, ':', conditionMessage(e)), 'error')
  })
}

still_missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (!ok || length(still_missing)) {
  emit('fatal', paste('Instalasi belum lengkap. Package yang masih hilang:', paste(still_missing, collapse = ', ')), 'error')
  quit(status = 3)
}

emit('package-install', 'Semua package R berhasil dipasang.', 'success', 100)
quit(status = 0)
