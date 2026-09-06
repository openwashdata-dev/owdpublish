# Small helpers shared by the pipeline steps.

owd_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")

owd_version <- function() "0.0.0.9000"

file_md5 <- function(path) unname(tools::md5sum(path))

text_md5 <- function(x) {
  tmp <- tempfile(); writeLines(x, tmp); on.exit(unlink(tmp)); file_md5(tmp)
}

random_suffix <- function(n = 6) {
  paste(sample(c(letters, 0:9), n, replace = TRUE), collapse = "")
}

write_json_file <- function(x, path) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null")
}

read_json_file <- function(path) {
  if (!file.exists(path)) return(list())
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

append_log <- function(path, line) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  cat(sprintf("%s %s\n", owd_now(), line), file = path, append = TRUE)
}

git_available <- function(path) {
  nzchar(Sys.which("git")) && file.exists(file.path(path, ".git", "HEAD"))
}

git_head <- function(path) {
  if (!git_available(path)) return(NA_character_)
  out <- suppressWarnings(system2("git", c("-C", shQuote(path), "rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE))
  if (length(out)) out[1] else NA_character_
}

git_commit_all <- function(path, message, trailers = character(), author = "owdpublish pipeline <pipeline@openwashdata.org>") {
  if (!nzchar(Sys.which("git"))) return(invisible(FALSE))
  if (!file.exists(file.path(path, ".git", "HEAD"))) {
    # a usethis step may have created .git/hooks without a repository; git init completes it
    system2("git", c("-C", shQuote(path), "init", "-q", "-b", "main"), stdout = FALSE, stderr = FALSE)
    stopifnot(file.exists(file.path(path, ".git", "HEAD")))
  }
  msg <- paste(c(message, "", trailers), collapse = "\n")
  tmp <- tempfile(); writeLines(msg, tmp); on.exit(unlink(tmp))
  system2("git", c("-C", shQuote(path), "add", "-A"), stdout = FALSE, stderr = FALSE)
  system2("git", c("-C", shQuote(path), "-c", "user.name=owdpublish", "-c", "user.email=pipeline@openwashdata.org",
                   "commit", "-q", "--author", shQuote(author), "-F", shQuote(tmp)), stdout = FALSE, stderr = FALSE)
  invisible(TRUE)
}

pkg_desc <- function(pkg) desc::desc(file = file.path(pkg, "DESCRIPTION"))

pkg_datasets <- function(pkg) {
  rda <- list.files(file.path(pkg, "data"), pattern = "\\.rda$", full.names = TRUE)
  out <- list()
  for (f in rda) {
    e <- new.env(); nm <- load(f, envir = e)[1]
    out[[nm]] <- e[[nm]]
  }
  out
}

read_dictionary <- function(pkg) {
  p <- file.path(pkg, "data-raw", "dictionary.csv")
  if (!file.exists(p)) return(NULL)
  d <- utils::read.csv(p, stringsAsFactors = FALSE, na.strings = c("", "NA"))
  d$file_name <- sub("\\.rda$", "", d$file_name)
  d
}

md_table <- function(df) {
  if (!nrow(df)) return("(none)")
  df[] <- lapply(df, function(x) gsub("\\|", "/", as.character(x)))
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  rows <- apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  paste(c(header, sep, rows), collapse = "\n")
}
