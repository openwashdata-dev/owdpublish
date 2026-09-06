#' The publication floor: required checks a package passes before review
#'
#' Modelled on the required tier of the openwashdata review standard.
#'
#' @param pkg Path to the package.
#' @return A data frame of check results, invisibly. Writes
#'   review/mechanical-report.md and review/mechanical.json.
owd_required_checks <- function(pkg) {
  d <- pkg_desc(pkg)
  has <- function(...) file.exists(file.path(pkg, ...))
  contract <- read_json_file(file.path(pkg, "review", "contract.json"))
  cff <- if (has("CITATION.cff")) yaml::read_yaml(file.path(pkg, "CITATION.cff")) else list()
  ai <- if (has("inst", "AI_USE.yml")) yaml::read_yaml(file.path(pkg, "inst", "AI_USE.yml")) else NULL
  checks <- list(
    list("title_and_description", "required", nzchar(d$get_field("Title")) && nzchar(d$get_field("Description"))),
    list("license_cc_by_4", "required", identical(d$get_field("License"), "CC BY 4.0")),
    list("maintainer_named", "required", any(grepl("cre", vapply(d$get_authors(), function(p) paste(p$role, collapse = ","), "")))),
    list("data_objects", "required", length(list.files(file.path(pkg, "data"), pattern = "\\.rda$")) > 0),
    list("raw_data_and_script", "required", has("data-raw", "data_processing.R")),
    list("dictionary", "required", has("data-raw", "dictionary.csv")),
    list("contract_pass", "required", isTRUE(contract$pass)),
    list("readme", "required", has("README.md")),
    list("citation_files_match", "required", has("CITATION.cff") && has("inst", "CITATION") && identical(as.character(cff$version), as.character(d$get_version()))),
    list("extdata_csv", "required", length(list.files(file.path(pkg, "inst", "extdata"), pattern = "\\.csv$")) > 0),
    list("r_cmd_check_workflow", "required", has(".github", "workflows", "R-CMD-check.yaml")),
    list("metadata_exports", "required", has("inst", "metadata", "datapackage.json") && has("inst", "metadata", "croissant.json") && has("inst", "metadata", "dataset.jsonld")),
    list("ai_use_statement", "required", !is.null(ai)),
    list("pkgdown_config", "advisory", has("_pkgdown.yml")),
    list("keywords", "advisory", !is.na(d$get_field("X-schema.org-keywords", default = NA_character_))),
    list("doi", "advisory", !is.null(cff$doi) || length(cff$identifiers) > 0),
    list("clearance_record", "advisory", has("data-raw", "clearance.json")),
    list("submission_record", "advisory", has("data-raw", "submission.yml"))
  )
  res <- do.call(rbind, lapply(checks, function(x) data.frame(check = x[[1]], tier = x[[2]], pass = isTRUE(x[[3]]), stringsAsFactors = FALSE)))
  pass <- all(res$pass[res$tier == "required"])
  dir.create(file.path(pkg, "review"), showWarnings = FALSE)
  writeLines(c(
    "# Mechanical report: the publication floor", "",
    sprintf("- tool: owdpublish %s, `owd_required_checks()`", owd_version()),
    sprintf("- package: %s %s, commit %s", d$get_field("Package"), d$get_version(), git_head(pkg)),
    sprintf("- run at: %s", owd_now()),
    sprintf("- result: %s (%d of %d required checks pass)", if (pass) "PASS" else "FAIL", sum(res$pass[res$tier == "required"]), sum(res$tier == "required")), "",
    "## Checks", "", md_table(res), ""
  ), file.path(pkg, "review", "mechanical-report.md"))
  write_json_file(list(tool = "owdpublish", version = owd_version(), run_at = owd_now(), commit = git_head(pkg), pass = pass, checks = res),
                  file.path(pkg, "review", "mechanical.json"))
  message(sprintf("Required checks: %s (%d of %d)", if (pass) "PASS" else "FAIL", sum(res$pass[res$tier == "required"]), sum(res$tier == "required")))
  invisible(res)
}

#' Advisory agent review with a provenance header
#'
#' In this prototype the "agent" is a deterministic set of readability and
#' plausibility heuristics. The header is the contract a real model run has to
#' honour: tool, model, prompt hash, run id, inputs. The report never decides.
#'
#' @param pkg Path to the package.
#' @param model Model identifier. "stub-deterministic-v1" in this prototype.
#' @param prompt Path to the prompt template. Defaults to the packaged template.
#' @return The report path, invisibly.
owd_agent_review <- function(pkg, model = "stub-deterministic-v1", prompt = NULL) {
  if (is.null(prompt)) prompt <- file.path("inst", "templates", "agent-review-prompt.md")
  prompt_text <- if (file.exists(prompt)) readLines(prompt, warn = FALSE) else "Review the data package for documentation quality and plausibility."
  m <- owd_metadata_model(pkg)
  datasets <- pkg_datasets(pkg)
  notes <- list()
  add <- function(dataset, variable, note) notes[[length(notes) + 1]] <<- data.frame(dataset = dataset, variable = variable, note = note, stringsAsFactors = FALSE)
  for (d in m$datasets) {
    df <- datasets[[d$name]]
    for (c in d$columns) {
      x <- df[[c$name]]; desc <- c$description
      if (!is.na(desc) && nchar(desc) < 25) add(d$name, c$name, "description is short; say what was measured, how, and in which unit")
      if (!is.na(desc) && grepl("\\b[A-Z]{2,}\\b", desc) && !grepl("\\(", desc)) add(d$name, c$name, "description uses an abbreviation without expanding it")
      if (is.numeric(x)) {
        v <- x[!is.na(x)]
        if (length(v) > 10) {
          z <- abs((v - mean(v)) / stats::sd(v)); n_out <- sum(z > 4, na.rm = TRUE)
          if (n_out > 0) add(d$name, c$name, sprintf("%d values lie more than 4 standard deviations from the mean; check plausibility", n_out))
        }
        if (grepl("distance|depth|volume|amount|price|cost|age|size|count", tolower(c$name)) && any(v < 0)) add(d$name, c$name, "negative values in a quantity that is usually non negative")
      }
      if (is.character(x) || is.factor(x)) {
        vals <- unique(as.character(x[!is.na(x)]))
        if (length(vals) > 1 && length(vals) < 50 && any(duplicated(tolower(trimws(vals))))) add(d$name, c$name, "categories differ only by case or spacing; harmonise them")
      }
      if (inherits(x, "Date")) {
        r <- range(x, na.rm = TRUE)
        if (r[1] < as.Date("1990-01-01") || r[2] > Sys.Date()) add(d$name, c$name, "dates fall outside 1990 to today")
      }
      if (mean(is.na(x)) > 0.3) add(d$name, c$name, sprintf("%.0f percent missing; say why in the documentation", 100 * mean(is.na(x))))
    }
  }
  findings <- if (length(notes)) do.call(rbind, notes) else data.frame(dataset = character(), variable = character(), note = character())
  inputs <- c(file.path(pkg, "DESCRIPTION"), file.path(pkg, "data-raw", "dictionary.csv"), list.files(file.path(pkg, "inst", "extdata"), pattern = "\\.csv$", full.names = TRUE))
  run <- list(tool = "owdpublish", version = owd_version(), model = model, prompt_md5 = text_md5(prompt_text),
              run_id = sprintf("run-%s-%s", format(Sys.time(), "%Y%m%d%H%M%S"), random_suffix(4)), run_at = owd_now(),
              advisory = TRUE, inputs = lapply(inputs, function(f) list(file = sub(paste0("^", pkg, "/?"), "", f), md5 = file_md5(f))),
              n_notes = nrow(findings))
  dir.create(file.path(pkg, "review"), showWarnings = FALSE)
  header <- c("---", sprintf("tool: owdpublish %s", owd_version()), sprintf("model: %s", model), sprintf("prompt_md5: %s", run$prompt_md5),
              sprintf("run_id: %s", run$run_id), sprintf("run_at: %s", run$run_at), "advisory: true",
              "inputs:", vapply(run$inputs, function(i) sprintf("  - %s (md5 %s)", i$file, i$md5), ""), "---", "")
  writeLines(c(header, "# Agent review (advisory)", "",
               "This report does not decide anything. Named reviewers read it after they have looked at the data themselves.", "",
               "## Notes", "", md_table(findings), ""), file.path(pkg, "review", "agent-report.md"))
  write_json_file(c(run, list(notes = findings)), file.path(pkg, "review", "agent-run.json"))
  message(sprintf("Agent review (advisory, %s): %d notes", model, nrow(findings)))
  invisible(file.path(pkg, "review", "agent-report.md"))
}

#' Credit a named reviewer in DESCRIPTION and open their report file
#'
#' @param pkg Path to the package.
#' @param given,family Reviewer name.
#' @param orcid ORCID iD, optional.
#' @return The report path, invisibly.
owd_credit_reviewer <- function(pkg, given, family, orcid = NULL) {
  d <- pkg_desc(pkg)
  comment <- if (!is.null(orcid)) c(ORCID = orcid) else NULL
  d$add_author(given = given, family = family, role = "rev", comment = comment)
  d$write()
  n <- length(list.files(file.path(pkg, "review"), pattern = "^reviewer-")) + 1
  path <- file.path(pkg, "review", sprintf("reviewer-%d.md", n))
  tpl <- file.path("inst", "templates", "reviewer-report.md")
  body <- if (file.exists(tpl)) readLines(tpl, warn = FALSE) else "# Reviewer report"
  body <- gsub("\\{\\{reviewer\\}\\}", paste(given, family), body)
  body <- gsub("\\{\\{date\\}\\}", format(Sys.Date()), body)
  body <- gsub("\\{\\{package\\}\\}", d$get_field("Package"), body)
  writeLines(body, path)
  message("Reviewer credited: ", given, " ", family, " (role rev), report at ", path)
  invisible(path)
}
