#' Submit a data file with a manifest into the secure staging area
#'
#' The staging area stands in for an access controlled space on an ETH
#' service. The directory is created with owner only permissions, the file is
#' copied in, the manifest is validated and stored next to it, and the queue
#' records the submission as received. Nothing leaves this directory until
#' clearance.
#'
#' @param file Path to the submitted data file (CSV in this prototype).
#' @param manifest A list or the path to a YAML file with the submission
#'   manifest (see inst/templates/submission.yml).
#' @param staging Directory of the staging area.
#' @return The submission id, invisibly.
owd_submit <- function(file, manifest, staging = "staging") {
  stopifnot(file.exists(file))
  m <- if (is.character(manifest) && length(manifest) == 1 && file.exists(manifest)) yaml::read_yaml(manifest) else manifest
  required <- c("title", "description", "research_question", "submitter_name", "submitter_email",
                "organisation", "country", "rights_holder", "rights_confirmed", "consent", "licence",
                "contains_personal_data")
  missing <- setdiff(required, names(m))
  if (length(missing)) stop("Manifest is missing: ", paste(missing, collapse = ", "))
  if (!isTRUE(m$rights_confirmed)) stop("The submitter has to confirm the right to license the data")
  if (!identical(m$licence, "CC-BY-4.0")) stop("Licence has to be CC-BY-4.0")
  if (!m$consent %in% c("none", "informed", "aggregated", "not_applicable")) {
    stop("consent has to be one of: none, informed, aggregated, not_applicable")
  }
  dir.create(staging, showWarnings = FALSE, recursive = TRUE)
  Sys.chmod(staging, "0700")
  id <- sprintf("sub-%s-%s", format(Sys.time(), "%Y%m%d"), random_suffix())
  dir <- file.path(staging, id)
  dir.create(dir); Sys.chmod(dir, "0700")
  file.copy(file, file.path(dir, basename(file)))
  Sys.chmod(file.path(dir, basename(file)), "0600")
  m$id <- id
  m$received <- owd_now()
  m$file <- basename(file)
  m$file_md5 <- file_md5(file)
  m$status <- "received"
  yaml::write_yaml(m, file.path(dir, "manifest.yml"))
  queue_update(staging, id, "received", m$title)
  append_log(file.path(staging, "intake.log"), sprintf("%s received: %s (%s)", id, m$title, m$file))
  message("Received ", id, ": ", m$title)
  invisible(id)
}

queue_update <- function(staging, id, status, title = NULL) {
  path <- file.path(staging, "queue.json")
  q <- read_json_file(path)
  found <- FALSE
  for (i in seq_along(q)) {
    if (identical(q[[i]]$id, id)) { q[[i]]$status <- status; q[[i]]$updated <- owd_now(); found <- TRUE }
  }
  if (!found) q[[length(q) + 1]] <- list(id = id, title = title, status = status, updated = owd_now())
  write_json_file(q, path)
  invisible(q)
}

read_manifest <- function(dir) yaml::read_yaml(file.path(dir, "manifest.yml"))
