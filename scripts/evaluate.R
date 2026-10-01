source("bootstrap.R");source("R/markov.R")
dir.create("reports",showWarnings=FALSE)
p<-base_transition();q<-scenario_transition(p,"absorbing")
report<-list(executed_at=as.character(Sys.Date()),source="synthetic academic scenario",seed=2026,
  assumptions=list(initial=c(A=500,B=500,C=500),horizon=40,failure=.05,repair=.25,return_station="A",trip_cost=.5,failure_cost=50,repair_cost=10),
  expected_trips_to_failure=absorption_expectation(q),comparison=compare_scenarios(p,c(500,500,500)),
  maintenance_stationary=stationary_distribution(scenario_transition(p,"maintenance")))
jsonlite::write_json(report,"reports/evaluation.json",pretty=TRUE,auto_unbox=TRUE,digits=8)
cat("Scenario report saved. These are mathematical expectations, not measured performance.\n")
