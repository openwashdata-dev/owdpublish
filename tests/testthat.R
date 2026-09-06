for (f in list.files("../R", full.names = TRUE)) source(f)
library(testthat)
test_dir("testthat")
