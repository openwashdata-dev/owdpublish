#' Generate the data paper from the package and render it
#'
#' Everything except the methods and provenance section and the limitations is
#' generated. Figures come from code chunks, never from imported images.
#'
#' @param pkg Path to the package.
#' @param render Render to HTML with Quarto (RStudio bundle) or rmarkdown.
#' @return The paper path, invisibly.
owd_data_paper <- function(pkg, render = TRUE) {
  m <- owd_metadata_model(pkg)
  d <- pkg_desc(pkg)
  sub <- if (file.exists(file.path(pkg, "data-raw", "submission.yml"))) yaml::read_yaml(file.path(pkg, "data-raw", "submission.yml")) else list()
  dict <- read_dictionary(pkg)
  ds <- m$datasets[[1]]
  df <- pkg_datasets(pkg)[[ds$name]]
  num <- names(df)[vapply(df, is.numeric, TRUE) & !grepl("lat|lon|id", tolower(names(df)))]
  cat_ <- names(df)[vapply(df, function(x) is.character(x) || is.factor(x), TRUE) & vapply(df, function(x) length(unique(x)) <= 12, TRUE)]
  fig <- if (length(num) && length(cat_)) sprintf(
    "```{r}\n#| label: fig-1\n#| fig-cap: \"%s by %s.\"\nlibrary(ggplot2)\nggplot(%s, aes(x = %s, y = %s)) + geom_boxplot() + labs(x = \"%s\", y = \"%s\") + theme_minimal()\n```",
    num[1], cat_[1], ds$name, cat_[1], num[1], cat_[1], num[1]) else if (length(num)) sprintf(
    "```{r}\n#| label: fig-1\n#| fig-cap: \"Distribution of %s.\"\nlibrary(ggplot2)\nggplot(%s, aes(x = %s)) + geom_histogram(bins = 30) + theme_minimal()\n```", num[1], ds$name, num[1]) else ""
  authors <- vapply(Filter(function(a) !grepl("rev|cph", a$role), m$authors), function(a) a$name, "")
  reviewers <- vapply(Filter(function(a) grepl("rev", a$role), m$authors), function(a) a$name, "")
  ai <- if (file.exists(file.path(pkg, "inst", "AI_USE.yml"))) yaml::read_yaml(file.path(pkg, "inst", "AI_USE.yml")) else NULL
  mech <- read_json_file(file.path(pkg, "review", "mechanical.json"))
  agent <- read_json_file(file.path(pkg, "review", "agent-run.json"))
  var_table <- if (!is.null(dict)) md_table(dict[dict$file_name == ds$name, c("variable_name", "variable_type", "description")]) else "(no dictionary)"
  qmd <- c(
    "---",
    sprintf("title: \"%s\"", m$title),
    "author:", sprintf("  - name: %s", authors),
    sprintf("date: %s", format(Sys.Date())),
    sprintf("abstract: \"%s\"", gsub("\"", "'", m$description)),
    "format:", "  html:", "    toc: true", "    embed-resources: true",
    "---", "",
    "```{r}", "#| include: false", sprintf("load(file.path('..', 'data', '%s.rda'))", ds$name), "```", "",
    "## Background and research question", "",
    sprintf("%s", sub$research_question %||% "[The submitter states the question this data was collected to answer.]"), "",
    sprintf("Data were collected in %s by %s.", sub$country %||% "[country]", sub$organisation %||% "[organisation]"), "",
    "## Data description", "",
    sprintf("The package `%s` holds one dataset, `%s`, with %d rows and %d variables.", m$name, ds$name, ds$rows, length(ds$columns)), "",
    var_table, "",
    "## A first look", "", fig, "",
    "## Methods and provenance", "",
    "[The author writes this section: how the data were collected, by whom, with which instrument, what was cleaned and why. This is the one part of the paper that is not generated.]", "",
    "## Limitations and reuse notes", "",
    "[The author writes this section: what the data cannot answer, known gaps, and the uses the author would warn against.]", "",
    "## Review", "",
    sprintf("- Publication floor: %s (%s)", if (isTRUE(mech$pass)) "passed" else "not passed", mech$run_at %||% "not run"),
    sprintf("- Advisory agent review: %s, run %s, %d notes, advisory only", agent$model %||% "none", agent$run_id %||% "none", agent$n_notes %||% 0L),
    sprintf("- Named reviewers: %s", if (length(reviewers)) paste(reviewers, collapse = ", ") else "[none yet]"), "",
    "## AI use statement", "",
    if (!is.null(ai)) c(ai$summary, "", vapply(ai$tasks, function(t) sprintf("- %s (%s; evidence: %s)", t$task, t$tool, t$evidence), ""), "", ai$rule) else "[generated after the disclosure step]", "",
    "## How to cite", "",
    sprintf("%s (%s). %s. Version %s. %s", paste(authors, collapse = ", "), format(Sys.Date(), "%Y"), m$title, m$version,
            if (!is.na(m$doi)) paste0("https://doi.org/", m$doi) else "DOI pending (Zenodo deposit is the next step)."), ""
  )
  dir.create(file.path(pkg, "paper"), showWarnings = FALSE)
  path <- file.path(pkg, "paper", "paper.qmd")
  writeLines(qmd, path)
  if (render) render_paper(pkg, path)
  message("Data paper written: ", path)
  invisible(path)
}

render_paper <- function(pkg, path) {
  quarto <- Sys.which("quarto")
  if (!nzchar(quarto)) {
    cands <- c("/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto", "/Applications/Positron.app/Contents/Resources/app/quarto/bin/quarto")
    quarto <- cands[file.exists(cands)][1]
  }
  if (!is.na(quarto) && nzchar(quarto)) {
    old <- setwd(dirname(path)); on.exit(setwd(old), add = TRUE)
    status <- system2(quarto, c("render", shQuote(basename(path)), "--to", "html"), stdout = FALSE, stderr = FALSE,
                      wait = TRUE, env = character())
    if (identical(status, 0L)) { message("Rendered with Quarto: ", sub("\\.qmd$", ".html", path)); return(invisible(TRUE)) }
    message("Quarto render failed (status ", status, "); falling back to rmarkdown")
  }
  if (requireNamespace("rmarkdown", quietly = TRUE)) {
    rmd <- sub("\\.qmd$", ".Rmd", path)
    txt <- readLines(path)
    txt <- gsub("^format:$", "output:", txt); txt <- gsub("^  html:$", "  html_document:", txt)
    txt <- txt[!grepl("embed-resources", txt)]
    writeLines(txt, rmd)
    rmarkdown::render(rmd, quiet = TRUE)
    message("Rendered with rmarkdown: ", sub("\\.Rmd$", ".html", rmd))
  }
  invisible(TRUE)
}
