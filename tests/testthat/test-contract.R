test_that("the contract check flags undocumented columns, type mismatches and short descriptions", {
  pkg <- tempfile("pkg"); dir.create(file.path(pkg, "data"), recursive = TRUE); dir.create(file.path(pkg, "data-raw"))
  survey <- data.frame(a = 1:3, b = c("x", "y", "z"), c = c(1.5, 2.5, NA), stringsAsFactors = FALSE)
  save(survey, file = file.path(pkg, "data", "survey.rda"))
  writeLines(c("directory,file_name,variable_name,variable_type,description",
               "data/,survey.rda,a,character,Identifier of the observation row",
               "data/,survey.rda,b,character,short"), file.path(pkg, "data-raw", "dictionary.csv"))
  f <- owd_contract_check(pkg)
  expect_true(any(f$check == "type" & f$variable == "a"))
  expect_true(any(f$check == "description" & f$variable == "b"))
  expect_true(any(f$check == "documented" & f$variable == "c"))
  expect_true(file.exists(file.path(pkg, "review", "contract.json")))
})
