#' Generate the AI use statement from the evidence in the package
#'
#' Sources: git trailers (`Assisted-by:`), the build log (mechanical
#' generation by washr through the pipeline), the agent review header. The
#' statement is generated first and checked afterwards; it is never written by
#' hand first.
#'
#' @param pkg Path to the package.
#' @return The statement list, invisibly. Writes inst/AI_USE.yml.
owd_ai_statement <- function(pkg) {
  d <- pkg_desc(pkg)
  tasks <- list()
  build <- read_json_file(file.path(pkg, "build", "build-log.json"))
  if (length(build)) tasks[[length(tasks) + 1]] <- list(
    task = "package scaffolding, data export, documentation stubs, citation files, JSON-LD",
    kind = "mechanical", tool = "washr 1.1.0 driven by owdpublish", evidence = "build/build-log.json",
    steps = vapply(build, function(s) s$step, ""))
  run <- read_json_file(file.path(pkg, "review", "agent-run.json"))
  if (length(run)) tasks[[length(tasks) + 1]] <- list(
    task = "advisory review of documentation quality and plausibility", kind = "agent",
    tool = run$model, run_id = run$run_id, prompt_md5 = run$prompt_md5, evidence = "review/agent-report.md",
    decides = FALSE)
  trailers <- character()
  if (git_available(pkg)) {
    log <- suppressWarnings(system2("git", c("-C", shQuote(pkg), "log", shQuote("--format=%H|%an|%s|%(trailers:key=Assisted-by,valueonly,separator=;)")), stdout = TRUE, stderr = FALSE))
    for (line in log) {
      parts <- strsplit(line, "|", fixed = TRUE)[[1]]
      if (length(parts) >= 4 && nzchar(parts[4])) {
        trailers <- c(trailers, parts[4])
        tasks[[length(tasks) + 1]] <- list(task = parts[3], kind = "assisted_commit", tool = parts[4], evidence = paste("commit", substr(parts[1], 1, 7)))
      }
    }
  }
  humans <- list()
  if (git_available(pkg)) {
    log <- suppressWarnings(system2("git", c("-C", shQuote(pkg), "log", shQuote("--format=%h|%an|%s|%(trailers:key=Assisted-by,valueonly)")), stdout = TRUE, stderr = FALSE))
    for (line in log) {
      parts <- strsplit(line, "|", fixed = TRUE)[[1]]
      if (length(parts) >= 3 && (length(parts) < 4 || !nzchar(parts[4]))) humans[[length(humans) + 1]] <- list(who = parts[2], what = parts[3], evidence = paste("commit", parts[1]))
    }
  }
  reviewers <- Filter(function(p) "rev" %in% p$role, d$get_authors())
  statement <- list(
    statement_version = "0.1", generated_at = owd_now(), generated_by = sprintf("owdpublish %s, owd_ai_statement()", owd_version()),
    package = d$get_field("Package"), version = as.character(d$get_version()),
    summary = sprintf("%d mechanical or agent assisted tasks are recorded with evidence; %d human commits carry no assistance trailer; %d named reviewers decided.",
                      length(tasks), length(humans), length(reviewers)),
    tasks = tasks,
    human_contributions = if (length(humans)) humans else list(list(who = "(none yet)", what = "methods and provenance section, limitations, decisions", evidence = "commits without Assisted-by trailer")),
    reviewers = lapply(reviewers, function(p) { o <- unname(p$comment["ORCID"]); list(name = paste(p$given, p$family), orcid = if (is.null(o) || is.na(o)) NULL else o) }),
    rule = "The deterministic tier is the floor. Agent output is advisory and logged. Named humans decide."
  )
  dir.create(file.path(pkg, "inst"), showWarnings = FALSE)
  yaml::write_yaml(statement, file.path(pkg, "inst", "AI_USE.yml"))
  message("AI use statement written: ", length(tasks), " assisted tasks, ", length(humans), " human commits")
  invisible(statement)
}

#' Check the AI use statement against the evidence
#'
#' @param pkg Path to the package.
#' @return TRUE when consistent; otherwise a character vector of problems.
owd_check_ai_statement <- function(pkg) {
  path <- file.path(pkg, "inst", "AI_USE.yml")
  if (!file.exists(path)) return("inst/AI_USE.yml is missing")
  s <- yaml::read_yaml(path)
  problems <- character()
  run <- read_json_file(file.path(pkg, "review", "agent-run.json"))
  if (length(run)) {
    ids <- unlist(lapply(s$tasks, function(t) t$run_id %||% NA_character_))
    if (!run$run_id %in% ids) problems <- c(problems, sprintf("agent run %s has no statement entry", run$run_id))
  }
  if (file.exists(file.path(pkg, "build", "build-log.json")) && !any(vapply(s$tasks, function(t) identical(t$kind, "mechanical"), TRUE)))
    problems <- c(problems, "build log exists but no mechanical task is declared")
  write_json_file(list(checked_at = owd_now(), consistent = !length(problems), problems = problems), file.path(pkg, "review", "ai-use-check.json"))
  if (length(problems)) problems else TRUE
}
