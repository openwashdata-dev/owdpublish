# End to end demo: a synthetic household water survey with fake personal data
# goes through submit, clear, build, check, review, publish and register.
# Run from the repository root: source("demo/run_demo.R")

for (f in list.files("R", full.names = TRUE)) source(f)
set.seed(20260906)
out <- "demo/out"; unlink(out, recursive = TRUE); dir.create(out, recursive = TRUE)
cat("\n== 0. synthetic submission with fake personal data ==\n")
n <- 200
villages <- c("Kaphuka", "Mbewe", "Chapananga", "Nyanja", "Dolo")
survey <- data.frame(
  household_id = sprintf("HH%03d", seq_len(n)),
  respondent_name = paste(sample(c("Amina", "Chikondi", "Dalitso", "Esnat", "Fatsani", "Grace"), n, TRUE), sample(c("Banda", "Phiri", "Mwale", "Chirwa", "Kamanga"), n, TRUE)),
  phone = sprintf("+265 99%d %03d %03d", sample(0:9, n, TRUE), sample(0:999, n, TRUE), sample(0:999, n, TRUE)),
  email = ifelse(runif(n) < 0.3, sprintf("person%d@example.org", seq_len(n)), NA),
  village = sample(villages, n, TRUE),
  district = "Chikwawa",
  latitude = round(-16.03 + runif(n, -0.2, 0.2), 6),
  longitude = round(34.78 + runif(n, -0.2, 0.2), 6),
  dob = as.character(as.Date("1960-01-01") + sample(0:16000, n, TRUE)),
  water_source = sample(c("borehole", "Borehole", "protected well", "unprotected well", "river", "piped"), n, TRUE, prob = c(.3, .05, .2, .2, .15, .1)),
  distance_m = round(pmax(0, rnorm(n, 450, 300))),
  hh_size = pmax(1L, as.integer(round(rnorm(n, 5, 2)))),
  ecoli_cfu_100ml = round(rexp(n, 1 / 40)),
  interview_date = as.character(as.Date("2025-03-01") + sample(0:80, n, TRUE)),
  stringsAsFactors = FALSE)
survey$ecoli_cfu_100ml[sample(n, 8)] <- NA
survey$distance_m[3] <- 9800   # one implausible value for the agent to notice
utils::write.csv(survey, file.path(out, "chikwawa_raw.csv"), row.names = FALSE, na = "")
manifest <- yaml::read_yaml("inst/templates/submission.yml")

cat("\n== 1. submit ==\n")
id <- owd_submit(file.path(out, "chikwawa_raw.csv"), manifest, staging = file.path(out, "staging"))

cat("\n== 2. clear ==\n")
rec <- owd_clear(id, staging = file.path(out, "staging"), cleared = file.path(out, "cleared"), decided_by = "Lars Schöbitz")
print(rec$pii_findings)
stopifnot(rec$decision == "cleared", rec$raw_deleted)

cat("\n== 3. build with washr ==\n")
descriptions <- c(
  household_id = "Identifier of the household, one row per household",
  village = "Name of the village where the household lives",
  district = "District of the survey, Chikwawa in this dataset",
  latitude = "Latitude of the household, rounded to two decimals (about one kilometre) at clearance",
  longitude = "Longitude of the household, rounded to two decimals (about one kilometre) at clearance",
  dob_age_band = "Age band of the respondent, derived from the date of birth at clearance",
  water_source = "Main drinking water source of the household as reported by the respondent",
  distance_m = "Walking distance from the dwelling to the main water source in metres",
  hh_size = "Number of people living in the household",
  ecoli_cfu_100ml = "E. coli count in colony forming units per 100 ml from a field test of the household's stored water",
  interview_date = "Date of the interview in ISO 8601 format")
pkg <- owd_build_package(id, cleared = file.path(out, "cleared"), packages = file.path(out, "packages"), name = "chikwawawater",
                         descriptions = descriptions, site = FALSE)

cat("\n== 4. contract check and metadata exports ==\n")
owd_contract_check(pkg)
owd_export_metadata(pkg)

cat("\n== 5. advisory agent review, named reviewers, AI use statement ==\n")
owd_agent_review(pkg)
owd_credit_reviewer(pkg, "Jane", "Doe")
owd_credit_reviewer(pkg, "John", "Roe")
# a human commit without an assistance trailer: the author writes the methods section
writeLines(c("# Methods and provenance", "", "Enumerators visited every fifth household on the village register between March and May 2025 and tested stored drinking water with a field kit."),
           file.path(pkg, "data-raw", "methods.md"))
git_commit_all(pkg, "docs: methods and provenance written by the author", author = "Amina Banda <amina@example.org>")
owd_ai_statement(pkg)
print(owd_check_ai_statement(pkg))

cat("\n== 6. publication floor ==\n")
res <- owd_required_checks(pkg)
print(res[!res$pass, ])

cat("\n== 7. data paper ==\n")
owd_data_paper(pkg, render = TRUE)

cat("\n== 8. registry ==\n")
owd_harvest(file.path(out, "packages"), file.path(out, "registry"))
cat("\n== done ==\n")
cat(readLines(file.path(out, "registry", "index.md")), sep = "\n")
