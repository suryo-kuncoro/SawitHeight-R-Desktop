options(warn = 1)

json_string <- function(x) encodeString(as.character(x), quote = '"')
json_array <- function(x) paste0('[', paste(vapply(x, json_string, character(1)), collapse = ','), ']')

required <- c('jsonlite', 'lidR', 'terra', 'sf', 'exactextractr', 'RCSF')
installed <- vapply(required, requireNamespace, logical(1), quietly = TRUE)
versions <- vapply(required, function(pkg) {
  if (requireNamespace(pkg, quietly = TRUE)) as.character(utils::packageVersion(pkg)) else ''
}, character(1))

package_entries <- vapply(seq_along(required), function(i) {
  paste0('{"name":', json_string(required[i]),
         ',"installed":', if (installed[i]) 'true' else 'false',
         ',"version":', json_string(versions[i]), '}')
}, character(1))

payload <- paste0(
  '{"type":"environment","status":', json_string(if (all(installed)) 'ready' else 'missing'),
  ',"r_version":', json_string(R.version.string),
  ',"r_home":', json_string(R.home()),
  ',"platform":', json_string(R.version$platform),
  ',"library_paths":', json_array(.libPaths()),
  ',"packages":[', paste(package_entries, collapse = ','), ']}')

cat('APP_EVENT:', payload, '\n', sep = '')
flush.console()
quit(status = 0)
