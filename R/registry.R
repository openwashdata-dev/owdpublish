#' Harvest every package into the thin registry
#'
#' Tables for people and machines, packages.json for r-universe, a schema.org
#' DataCatalog for search engines, a listing page, a sitemap. No portal.
#'
#' @param packages Directory holding the packages.
#' @param out Output directory of the registry.
#' @return Paths written, invisibly.
owd_harvest <- function(packages = "packages", out = "registry") {
  dirs <- Filter(function(p) file.exists(file.path(p, "DESCRIPTION")), list.dirs(packages, recursive = FALSE))
  pk <- list(); ds <- list(); vars <- list(); catalog <- list(); reg <- list()
  for (p in dirs) {
    m <- owd_metadata_model(p)
    mech <- read_json_file(file.path(p, "review", "mechanical.json"))
    maint <- Filter(function(a) grepl("cre", a$role), m$authors)
    pk[[length(pk) + 1]] <- data.frame(
      package = m$name, title = m$title, version = m$version, doi = m$doi, license = m$license,
      published = !is.na(m$doi), floor_passed = isTRUE(mech$pass), reviewed_at = mech$run_at %||% NA_character_,
      n_reviewers = sum(vapply(m$authors, function(a) grepl("rev", a$role), TRUE)),
      n_datasets = length(m$datasets), maintainer = if (length(maint)) maint[[1]]$name else NA_character_,
      spatial = m$spatial, keywords = paste(m$keywords, collapse = "; "), url = m$repository, site = m$site, stringsAsFactors = FALSE)
    for (d in m$datasets) {
      ds[[length(ds) + 1]] <- data.frame(package = m$name, dataset = d$name, rows = d$rows, columns = length(d$columns), file = d$file, md5 = d$md5, stringsAsFactors = FALSE)
      for (c in d$columns) vars[[length(vars) + 1]] <- data.frame(package = m$name, dataset = d$name, variable = c$name, type = c$type, description = c$description, stringsAsFactors = FALSE)
    }
    if (file.exists(file.path(p, "inst", "metadata", "dataset.jsonld"))) catalog[[length(catalog) + 1]] <- read_json_file(file.path(p, "inst", "metadata", "dataset.jsonld"))
    reg[[length(reg) + 1]] <- list(package = m$name, url = m$repository)
  }
  dir.create(out, showWarnings = FALSE, recursive = TRUE)
  packages_df <- do.call(rbind, pk); datasets_df <- do.call(rbind, ds); vars_df <- do.call(rbind, vars)
  utils::write.csv(packages_df, file.path(out, "packages.csv"), row.names = FALSE, na = "")
  utils::write.csv(datasets_df, file.path(out, "datasets.csv"), row.names = FALSE, na = "")
  utils::write.csv(vars_df, file.path(out, "variables.csv"), row.names = FALSE, na = "")
  write_json_file(reg, file.path(out, "packages.json"))
  write_json_file(list(`@context` = "https://schema.org", `@type` = "DataCatalog", name = "openwashdata", url = "https://openwashdata.org", dataset = catalog),
                  file.path(out, "catalog.jsonld"))
  sites <- packages_df$site[!is.na(packages_df$site)]
  writeLines(c('<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
               sprintf("  <url><loc>%s</loc><lastmod>%s</lastmod></url>", sites, format(Sys.Date())), "</urlset>"), file.path(out, "sitemap.xml"))
  listing <- packages_df[, c("package", "title", "version", "published", "floor_passed", "n_reviewers", "n_datasets", "spatial", "maintainer")]
  writeLines(c("# openwashdata registry", "", sprintf("Harvested %s. %d packages, %d datasets, %d variables.", owd_now(), nrow(packages_df), nrow(datasets_df), nrow(vars_df)), "",
               md_table(listing), "", "Exports: packages.csv, datasets.csv, variables.csv, packages.json (r-universe), catalog.jsonld (schema.org DataCatalog), sitemap.xml.",
               "Next: a Zenodo community, HDX where in scope, Renku data connectors from the DOIs."), file.path(out, "index.md"))
  message(sprintf("Registry: %d packages, %d datasets, %d variables -> %s", nrow(packages_df), nrow(datasets_df), nrow(vars_df), out))
  invisible(list.files(out, full.names = TRUE))
}
