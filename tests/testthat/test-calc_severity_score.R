context("Calculate prevalence")
library(ostRc)
library(tidyr)
library(dplyr)
library(magrittr)
library(testthat)

# example vectors used in more than one test
q1 <- c(17, 8, 8, 0)
q2_v2 <- c(25, 17, 17, 0)
q3_v2 <- c(25, 8, 17, 0)
q4 <- c(25, 8, 0, 0)

test_that("Returns a vector with correct number of sumscores.", {
  length_q1 <- length(q1)
  sumscores_test <- calc_severity_score(q1, q2_v2, q3_v2, q4)
  expect_length(sumscores_test, length_q1)
})

test_that("Sumscores are correct.", {
  sumscores_correct <- q1 + q2_v2 + q3_v2 + q4
  sumscores_test <- calc_severity_score(q1, q2_v2, q3_v2, q4)
  expect_equal(sumscores_test, sumscores_correct)
})

test_that("Returns a value of NA if one ore more responses are missing.", {
  q4_na <- c(25, 8, 0, NA)
  sumscores_correct <- c(92, 41, 42, NA)
  sumscores_test <- calc_severity_score(q1, q2_v2, q3_v2, q4_na)
  expect_equal(sumscores_test, sumscores_correct)
})

test_that("Sum is smaller or equal to 100.", {
  sumscores_test <- calc_severity_score(q1, q2_v2, q3_v2, q4)
  for (i in length(sumscores_test)) {
    expect_lte(sumscores_test[i], 100)
  }
})

test_that("Will throw error if answers are not in the classic 0, 8, 17, 25 or 0, 6, 13, 19, 25 values.", {
  q2_wrongcodes <- c(0, 1, 2, 3)
  q3_wrongcodes <- c(1, 2, 3, 99)
  expect_error(calc_severity_score(q1, q2_wrongcodes, q3_v2, q4))
  expect_error(calc_severity_score(q1, q2_v2, q3_wrongcodes, q4))
})

test_that("Throws error if any of the scores are non-numeric.", {
  q2_wrongcodes <- c("one", "two", "2", "3")
  q3_wrongcodes <- c(TRUE, FALSE, TRUE, FALSE)
  expect_error(calc_severity_score(q1, q2_wrongcodes, q3_v2, q4))
  expect_error(calc_severity_score(q1, q2_v2, q3_wrongcodes, q4))
})
