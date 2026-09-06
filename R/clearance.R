#' Scan a data frame for personal or sensitive information
#'
#' Heuristics only: emails, phone numbers, columns that name people, GPS
#' columns with more precision than a village, birth dates, identity numbers.
#' Returns one row per finding with the action the clearance step applies.
#'
#' @param data A data frame.
#' @return A data frame with columns column, type, hits, action.
owd_scan_pii <- function(data) {
  findings <- list()
  add <- function(column, type, hits, action) {
    findings[[length(findings) + 1]] <<- data.frame(column = column, type = type, hits = as.integer(hits),
                                                    action = action, stringsAsFactors = FALSE)
  }
  email_re <- "[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[[:alpha:]]{2,}"
  phone_re <- "\\+?[0-9][0-9 ()./-]{6,}[0-9]"
  name_cols <- "(^|_)(name|first|last|surname|respondent|enumerator|interviewer|head)($|_)"
  gps_cols <- "(^|_)(lat|latitude|lon|long|longitude|gps|coord|x|y)($|_)"
  dob_cols <- "(^|_)(dob|birth|birthdate|birthday)($|_)"
  id_cols  <- "(^|_)(national_id|id_number|passport|nin|ssn)($|_)"
  for (col in names(data)) {
    x <- data[[col]]; lc <- tolower(col)
    if (is.character(x) || is.factor(x)) {
      xs <- as.character(x); xs <- xs[!is.na(xs)]
      n_email <- sum(grepl(email_re, xs))
      if (n_email > 0) add(col, "email", n_email, "drop")
      digits <- nchar(gsub("[^0-9]", "", xs))
      is_date <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", xs)
      n_phone <- sum(grepl(phone_re, xs) & digits >= 7 & digits <= 15 & !is_date)
      if (n_phone > 0 && n_phone >= 0.5 * length(xs)) add(col, "phone", n_phone, "drop")
      if (grepl(name_cols, lc)) add(col, "person_name", length(xs), "drop")
      if (grepl(id_cols, lc)) add(col, "id_number", length(xs), "drop")
    }
    if (is.numeric(x)) {
      if (grepl("phone|mobile|tel", lc)) add(col, "phone", sum(!is.na(x)), "drop")
      if (grepl(id_cols, lc)) add(col, "id_number", sum(!is.na(x)), "drop")
      if (grepl(gps_cols, lc)) {
        v <- x[!is.na(x)]
        dec <- if (length(v)) max(vapply(v, function(z) {
          s <- sub("^-?[0-9]+\\.?", "", formatC(z, format = "f", digits = 8)); nchar(sub("0+$", "", s))
        }, numeric(1))) else 0
        if (dec > 2) add(col, "gps_precision", length(v), "round_2")
      }
    }
    if (grepl(dob_cols, lc)) add(col, "birth_date", sum(!is.na(x)), "age_band")
  }
  if (length(findings)) do.call(rbind, findings) else
    data.frame(column = character(), type = character(), hits = integer(), action = character(), stringsAsFactors = FALSE)
}

apply_pii_actions <- function(data, findings) {
  for (i in seq_len(nrow(findings))) {
    col <- findings$column[i]; act <- findings$action[i]
    if (!col %in% names(data)) next
    if (act == "drop") data[[col]] <- NULL
    if (act == "round_2") data[[col]] <- round(data[[col]], 2)
    if (act == "age_band") {
      yr <- suppressWarnings(as.integer(format(as.Date(data[[col]]), "%Y")))
      age <- as.integer(format(Sys.Date(), "%Y")) - yr
      data[[col]] <- NULL
      data[[paste0(col, "_age_band")]] <- cut(age, c(-1, 17, 29, 44, 59, 200), labels = c("0-17", "18-29", "30-44", "45-59", "60+"))
    }
  }
  data
}

#' Clear a submission: checklist, sensitivity scan, actions, decision, deletion
#'
#' @param id Submission id from [owd_submit()].
#' @param staging Staging directory.
#' @param cleared Directory that receives cleared data (public from here on).
#' @param decided_by Name of the person taking the decision.
#' @param llm_hook Optional function(data_sample, manifest) returning notes from
#'   a language model assisted scan. Not configured in this prototype.
#' @return The clearance record, invisibly.
owd_clear <- function(id, staging = "staging", cleared = "cleared", decided_by, llm_hook = NULL) {
  dir <- file.path(staging, id)
  m <- read_manifest(dir)
  raw_path <- file.path(dir, m$file)
  data <- utils::read.csv(raw_path, stringsAsFactors = FALSE, check.names = FALSE)
  checks <- list(
    rights_confirmed = isTRUE(m$rights_confirmed),
    licence_cc_by = identical(m$licence, "CC-BY-4.0"),
    consent_matches_personal_data = !(isTRUE(m$contains_personal_data) && identical(m$consent, "none")),
    file_hash_matches = identical(file_md5(raw_path), m$file_md5)
  )
  findings <- owd_scan_pii(data)
  llm_notes <- if (is.function(llm_hook)) llm_hook(utils::head(data, 20), m) else
    "language model assisted scan: not configured in this prototype; heuristic scan only"
  decision <- if (all(unlist(checks))) "cleared" else "refused"
  record <- list(
    id = id, title = m$title, decided_by = decided_by, decided_at = owd_now(), decision = decision,
    checks = checks,
    pii_findings = if (nrow(findings)) findings else list(),
    llm_notes = llm_notes,
    rows = nrow(data), columns_before = ncol(data)
  )
  if (decision == "cleared") {
    out <- apply_pii_actions(data, findings)
    odir <- file.path(cleared, id); dir.create(odir, showWarnings = FALSE, recursive = TRUE)
    utils::write.csv(out, file.path(odir, "data.csv"), row.names = FALSE, na = "")
    m$status <- "cleared"; m$submitter_email <- NULL  # the public copy of the manifest carries no email
    yaml::write_yaml(m, file.path(odir, "manifest.yml"))
    record$columns_after <- ncol(out)
    record$cleared_file <- file.path(odir, "data.csv")
    record$cleared_md5 <- file_md5(record$cleared_file)
  }
  # custody ends here: the raw file is deleted whatever the decision
  unlink(raw_path)
  record$raw_deleted <- !file.exists(raw_path)
  record$raw_md5 <- m$file_md5
  if (decision == "cleared") write_json_file(record, file.path(cleared, id, "clearance.json"))
  write_json_file(record[c("id", "decision", "decided_by", "decided_at", "raw_deleted")], file.path(dir, "clearance-stub.json"))
  queue_update(staging, id, decision)
  append_log(file.path(staging, "intake.log"), sprintf("%s %s by %s; raw deleted: %s; findings: %d", id, decision, decided_by, record$raw_deleted, nrow(findings)))
  message(id, " ", decision, " (", nrow(findings), " sensitivity findings, raw file deleted)")
  invisible(record)
}
