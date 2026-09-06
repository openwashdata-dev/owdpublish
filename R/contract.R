#' Check the data dictionary against the data (the data contract)
#'
#' Required findings block publication; advisory findings are reported.
#'
#' @param pkg Path to the package.
#' @return A data frame of findings, invisibly. Writes review/contract-report.md
#'   and review/contract.json.
owd_contract_check <- function(pkg) {
  dict <- read_dictionary(pkg)
  datasets <- pkg_datasets(pkg)
  rows <- list()
  add <- function(dataset, variable, check, tier, message) {
    rows[[length(rows) + 1]] <<- data.frame(dataset = dataset, variable = variable, check = check, tier = tier,
                                            message = message, stringsAsFactors = FALSE)
  }
  if (is.null(dict)) add("(package)", "", "dictionary_present", "required", "data-raw/dictionary.csv is missing")
  if (!length(datasets)) add("(package)", "", "data_present", "required", "no data object under data/")
  for (nm in names(datasets)) {
    df <- datasets[[nm]]
    d <- if (is.null(dict)) dict[0, ] else dict[dict$file_name == nm, ]
    for (col in setdiff(names(df), d$variable_name)) add(nm, col, "documented", "required", "column has no dictionary row")
    for (v in setdiff(d$variable_name, names(df))) add(nm, v, "exists", "required", "dictionary row has no column in the data")
    for (i in seq_len(nrow(d))) {
      v <- d$variable_name[i]; if (!v %in% names(df)) next
      actual <- class(df[[v]])[1]
      if (!identical(actual, d$variable_type[i])) add(nm, v, "type", "required", sprintf("dictionary says %s, data is %s", d$variable_type[i], actual))
      desc <- d$description[i]
      if (is.na(desc) || nchar(trimws(desc)) < 10 || grepl("to be written", desc)) add(nm, v, "description", "required", "description missing or shorter than 10 characters")
    }
    for (col in names(df)) {
      x <- df[[col]]
      if (all(is.na(x))) add(nm, col, "all_missing", "advisory", "every value is missing")
      if (grepl("(^|_)id$", tolower(col)) && anyDuplicated(x[!is.na(x)])) add(nm, col, "unique_id", "advisory", "identifier column has duplicates")
      if (is.numeric(x) && grepl("(^n_|count|number|size|_n$)", tolower(col)) && any(x < 0, na.rm = TRUE)) add(nm, col, "negative_count", "advisory", "count-like column has negative values")
      if (mean(is.na(x)) > 0.3) add(nm, col, "missingness", "advisory", sprintf("%.0f percent missing", 100 * mean(is.na(x))))
    }
  }
  findings <- if (length(rows)) do.call(rbind, rows) else
    data.frame(dataset = character(), variable = character(), check = character(), tier = character(), message = character(), stringsAsFactors = FALSE)
  n_req <- sum(findings$tier == "required"); n_adv <- sum(findings$tier == "advisory")
  dir.create(file.path(pkg, "review"), showWarnings = FALSE)
  report <- c(
    "# Contract report: dictionary against data", "",
    sprintf("- tool: owdpublish %s, `owd_contract_check()`", owd_version()),
    sprintf("- package commit: %s", git_head(pkg)),
    sprintf("- run at: %s", owd_now()),
    sprintf("- result: %s (%d required, %d advisory)", if (n_req == 0) "PASS" else "FAIL", n_req, n_adv), "",
    "## Findings", "", md_table(findings), ""
  )
  writeLines(report, file.path(pkg, "review", "contract-report.md"))
  write_json_file(list(tool = "owdpublish", version = owd_version(), run_at = owd_now(), commit = git_head(pkg),
                       pass = n_req == 0, required = n_req, advisory = n_adv, findings = findings),
                  file.path(pkg, "review", "contract.json"))
  message(sprintf("Contract check: %s (%d required, %d advisory)", if (n_req == 0) "PASS" else "FAIL", n_req, n_adv))
  invisible(findings)
}
