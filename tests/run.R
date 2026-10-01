source("bootstrap.R")
source("R/markov.R")
testthat::test_dir("tests/testthat",reporter="summary",stop_on_failure=TRUE)
