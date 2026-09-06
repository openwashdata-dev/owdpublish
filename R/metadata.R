#' One metadata model from the package files
#'
#' Reads DESCRIPTION, the dictionary, CITATION.cff and the data, and returns a
#' list that the three renderers share.
#'
#' @param pkg Path to the package.
owd_metadata_model <- function(pkg) {
  d <- pkg_desc(pkg)
  authors <- d$get_authors()
  cff <- if (file.exists(file.path(pkg, "CITATION.cff"))) yaml::read_yaml(file.path(pkg, "CITATION.cff")) else list()
  doi <- cff$doi %||% NA_character_
  if (is.na(doi) && length(cff$identifiers)) {
    ids <- Filter(function(i) identical(i$type, "doi"), cff$identifiers); if (length(ids)) doi <- ids[[1]]$value
  }
  dict <- read_dictionary(pkg)
  datasets <- lapply(names(pkg_datasets(pkg)), function(nm) {
    df <- pkg_datasets(pkg)[[nm]]
    dd <- if (is.null(dict)) NULL else dict[dict$file_name == nm, ]
    cols <- lapply(names(df), function(col) list(
      name = col, type = class(df[[col]])[1],
      description = if (!is.null(dd) && col %in% dd$variable_name) dd$description[dd$variable_name == col][1] else NA_character_))
    list(name = nm, file = paste0("inst/extdata/", nm, ".csv"), rows = nrow(df), columns = cols,
         md5 = if (file.exists(file.path(pkg, "inst", "extdata", paste0(nm, ".csv")))) file_md5(file.path(pkg, "inst", "extdata", paste0(nm, ".csv"))) else NA_character_)
  })
  kw <- d$get_field("X-schema.org-keywords", default = NA_character_)
  url <- d$get_field("URL", default = NA_character_)
  list(
    name = d$get_field("Package"), title = d$get_field("Title"), description = d$get_field("Description"),
    version = as.character(d$get_version()), license = d$get_field("License"), doi = doi,
    authors = lapply(authors, function(p) list(
      name = paste(c(p$given, p$family), collapse = " "), given = p$given, family = p$family,
      role = paste(p$role, collapse = ","), orcid = unname(p$comment["ORCID"]) %||% NA_character_)),
    keywords = if (is.na(kw)) character() else trimws(strsplit(kw, ",")[[1]]),
    spatial = d$get_field("X-schema.org-spatialCoverage", default = NA_character_),
    temporal = d$get_field("X-schema.org-temporalCoverage", default = NA_character_),
    repository = url,
    site = if (!is.na(url)) sub("https://github.com/([^/]+)/([^/]+)", "https://\\1.github.io/\\2/", url) else NA_character_,
    datasets = datasets
  )
}

license_url <- function(license) {
  if (grepl("CC BY 4.0|CC-BY-4.0", license)) "https://creativecommons.org/licenses/by/4.0/" else license
}

fr_type <- function(type) switch(type, character = "string", factor = "string", numeric = "number", double = "number",
                                 integer = "integer", logical = "boolean", Date = "date", "string")
cr_type <- function(type) switch(type, character = "sc:Text", factor = "sc:Text", numeric = "sc:Float", double = "sc:Float",
                                 integer = "sc:Integer", logical = "sc:Boolean", Date = "sc:Date", "sc:Text")

to_frictionless <- function(m) {
  list(
    name = m$name, title = m$title, description = m$description, version = m$version,
    licenses = list(list(name = "CC-BY-4.0", path = license_url(m$license), title = "Creative Commons Attribution 4.0")),
    homepage = m$site, id = if (!is.na(m$doi)) paste0("https://doi.org/", m$doi) else NULL,
    keywords = m$keywords,
    contributors = lapply(m$authors, function(a) list(title = a$name, role = if (grepl("cre", a$role)) "maintainer" else if (grepl("rev", a$role)) "reviewer" else "author")),
    resources = lapply(m$datasets, function(d) list(
      name = d$name, path = d$file, format = "csv", mediatype = "text/csv", encoding = "utf-8",
      hash = if (!is.na(d$md5)) paste0("md5:", d$md5) else NULL,
      schema = list(fields = lapply(d$columns, function(c) list(name = c$name, type = fr_type(c$type), description = c$description)))))
  )
}

to_croissant <- function(m) {
  context <- list(`@language` = "en", `@vocab` = "https://schema.org/", citeAs = "cr:citeAs", column = "cr:column",
                  conformsTo = "dct:conformsTo", cr = "http://mlcommons.org/croissant/", rai = "http://mlcommons.org/croissant/RAI/",
                  data = list(`@id` = "cr:data", `@type` = "@json"), dataType = list(`@id` = "cr:dataType", `@type` = "@vocab"),
                  dct = "http://purl.org/dc/terms/", examples = list(`@id` = "cr:examples", `@type` = "@json"),
                  extract = "cr:extract", field = "cr:field", fileProperty = "cr:fileProperty", fileObject = "cr:fileObject",
                  fileSet = "cr:fileSet", format = "cr:format", includes = "cr:includes", isLiveDataset = "cr:isLiveDataset",
                  jsonPath = "cr:jsonPath", key = "cr:key", md5 = "cr:md5", parentField = "cr:parentField", path = "cr:path",
                  recordSet = "cr:recordSet", references = "cr:references", regex = "cr:regex", repeated = "cr:repeated",
                  replace = "cr:replace", sc = "https://schema.org/", separator = "cr:separator", source = "cr:source",
                  subField = "cr:subField", transform = "cr:transform")
  base <- if (!is.na(m$repository)) paste0(sub("github.com", "raw.githubusercontent.com", m$repository), "/main/") else ""
  list(
    `@context` = context, `@type` = "sc:Dataset", conformsTo = "http://mlcommons.org/croissant/1.0",
    name = m$name, description = m$description, version = m$version, license = license_url(m$license),
    url = m$site, citeAs = if (!is.na(m$doi)) paste0("https://doi.org/", m$doi) else m$repository, keywords = m$keywords,
    creator = lapply(m$authors, function(a) list(`@type` = "sc:Person", name = a$name)),
    distribution = lapply(m$datasets, function(d) list(`@type` = "cr:FileObject", `@id` = paste0(d$name, ".csv"), name = paste0(d$name, ".csv"),
                                                        contentUrl = paste0(base, d$file), encodingFormat = "text/csv", md5 = d$md5)),
    recordSet = lapply(m$datasets, function(d) list(
      `@type` = "cr:RecordSet", `@id` = d$name, name = d$name, description = paste("Rows of", d$name),
      field = lapply(d$columns, function(c) list(
        `@type` = "cr:Field", `@id` = paste0(d$name, "/", c$name), name = c$name, description = c$description, dataType = cr_type(c$type),
        source = list(fileObject = list(`@id` = paste0(d$name, ".csv")), extract = list(column = c$name))))))
  )
}

to_schemaorg <- function(m) {
  list(
    `@context` = "https://schema.org", `@type` = "Dataset", name = m$title, alternateName = m$name,
    description = m$description, license = license_url(m$license), version = m$version,
    identifier = if (!is.na(m$doi)) paste0("https://doi.org/", m$doi) else m$repository, url = m$site,
    keywords = m$keywords, spatialCoverage = m$spatial, temporalCoverage = m$temporal,
    creator = lapply(m$authors, function(a) list(`@type` = "Person", name = a$name, identifier = if (!is.na(a$orcid)) paste0("https://orcid.org/", a$orcid) else NULL)),
    includedInDataCatalog = list(`@type` = "DataCatalog", name = "openwashdata", url = "https://openwashdata.org"),
    distribution = lapply(m$datasets, function(d) list(`@type` = "DataDownload", name = paste0(d$name, ".csv"), encodingFormat = "text/csv",
                                                        contentUrl = paste0(sub("github.com", "raw.githubusercontent.com", m$repository), "/main/", d$file))),
    variableMeasured = unlist(lapply(m$datasets, function(d) lapply(d$columns, function(c) list(`@type` = "PropertyValue", name = c$name, description = c$description))), recursive = FALSE)
  )
}

#' Export the three metadata renderings into inst/metadata
#'
#' @param pkg Path to the package.
#' @return Paths written, invisibly.
owd_export_metadata <- function(pkg) {
  m <- owd_metadata_model(pkg)
  out <- file.path(pkg, "inst", "metadata")
  paths <- c(datapackage = file.path(out, "datapackage.json"), croissant = file.path(out, "croissant.json"), schemaorg = file.path(out, "dataset.jsonld"))
  write_json_file(to_frictionless(m), paths[["datapackage"]])
  write_json_file(to_croissant(m), paths[["croissant"]])
  write_json_file(to_schemaorg(m), paths[["schemaorg"]])
  message("Metadata exported: ", paste(basename(paths), collapse = ", "))
  invisible(paths)
}
