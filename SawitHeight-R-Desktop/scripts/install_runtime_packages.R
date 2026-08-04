args <- commandArgs(trailingOnly = TRUE)
lib <- if (length(args)) normalizePath(args[[1]], winslash = '/', mustWork = FALSE) else file.path(R.home(), 'library')
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))

packages <- c('jsonlite', 'lidR', 'terra', 'sf', 'exactextractr', 'RCSF')
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  install.packages(
    missing,
    lib = lib,
    repos = 'https://cloud.r-project.org',
    dependencies = TRUE,
    type = .Platform$pkgType
  )
}
still_missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(still_missing)) stop('Bundled R belum lengkap: ', paste(still_missing, collapse = ', '))
cat('Bundled R packages ready in:', lib, '\n')
for (pkg in packages) cat(pkg, as.character(packageVersion(pkg)), '\n')
