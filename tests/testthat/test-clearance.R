test_that("the sensitivity scan finds emails, phones, names, precise GPS and birth dates", {
  df <- data.frame(
    id = 1:3, respondent_name = c("A B", "C D", "E F"), email = c("a@x.org", "b@x.org", NA),
    phone = c("+265 991 234 567", "0999 123 456", "0888 555 666"), latitude = c(-15.123456, -15.234567, -15.345678),
    dob = c("1980-01-01", "1995-06-30", "2001-12-12"), village = c("Kaphuka", "Mbewe", "Kaphuka"), stringsAsFactors = FALSE)
  f <- owd_scan_pii(df)
  expect_true(all(c("email", "phone", "person_name", "gps_precision", "birth_date") %in% f$type))
  expect_false("village" %in% f$column)
  out <- apply_pii_actions(df, f)
  expect_false(any(c("respondent_name", "email", "phone", "dob") %in% names(out)))
  expect_equal(out$latitude, round(df$latitude, 2))
  expect_true("dob_age_band" %in% names(out))
})

test_that("clean data produce no findings", {
  df <- data.frame(village = c("A", "B"), hh_size = c(4L, 6L), water_source = c("borehole", "river"))
  expect_equal(nrow(owd_scan_pii(df)), 0)
})
