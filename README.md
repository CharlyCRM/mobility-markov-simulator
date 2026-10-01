# Mobility Markov Simulator

**Carlos Ramírez Martín · R / Shiny / linear algebra / Monte Carlo**

An interactive fleet model extending my UOC linear-algebra coursework. Three stations, a failure state and three explicit scenarios: mobility without failures, absorbing failure, and maintenance with return to service. Spanish/English UI.

## Run locally

Requires R 4.4.2 or compatible newer R:

```sh
Rscript setup.R
Rscript tests/run.R
Rscript run.R
```

Open http://127.0.0.1:8505/ (`/?lang=en` for English). Loopback only; no Railway deployment. Exact dependency restoration: `renv::restore(lockfile='renv.lock', library='.library', prompt=FALSE)` after installing renv.

## Explore

- Edit the mobility matrix, initial fleet, failure/repair probabilities and return station.
- Inspect or animate transition steps and compare analytic expectations with seeded Monte Carlo.
- See stationary distributions, expected trips until absorbing failure, availability and illustrative costs.
- Download the transition matrix, trajectories and scenario comparison as JSON.

Every row must contain probabilities in [0,1] summing to one. Invalid inputs are rejected rather than silently normalized. Fleet counts are whole, nonnegative and bounded to 300,000 for the interactive app. Calculated expectations may be fractional; simulation conserves integer fleet size exactly.

## Mathematical model

Rows encode origin → destination. With row-vector fleet `n`, the next expected fleet is `nP`. A failed active bicycle enters `T` with probability `f`; other movement probabilities are multiplied by `1-f`. Maintenance returns a bicycle from `T` to a selected station with probability `r`.

A step is a **transition opportunity, not an hour**: active bicycles make a trip, while those in T wait or return after repair. Failure is independent and constant across active states. There are no station capacities, rebalancing trucks, time-varying demand, purchase costs or revenue. Scenario costs count active trips, entries into failure and completed repairs over the selected horizon.

For absorbing failure with `f=0.05`, the fundamental matrix gives **20 expected trips** until failure from each station. With `r=0.25`, the maintenance model's stationary availability is `r/(r+f) = 83.333%`. A stationary equilibrium does not necessarily imply trajectory convergence for periodic chains; nonunique stationary distributions are explicitly reported.

`reports/evaluation.json` records the default scenario: 1,500 bicycles, 40 transition opportunities, failure .05, repair .25, return to A. It contains mathematical expectations under hypothetical assumptions, **not measured fleet performance or an economic recommendation**. Monte Carlo is a single seeded realization, not a confidence interval.

## Tests and provenance

Tests cover stochastic-matrix validation, nonnegative trajectories, exact fleet conservation, reproducible simulation, the 20-trip analytic result, repair boundaries, stationary uniqueness, Monte Carlo approximation and event-based costs.

```sh
Rscript scripts/evaluate.R
Rscript scripts/verify-originals.R /path/to/UOC
```

The original PEC5 is an immutable read-only input; its SHA-256 is recorded in `provenance/source-manifest.json`. An archival working copy is ignored by Git. The public project contains independently rebuilt code and academic parameter values, not institutional prompts or teaching PDFs. MIT applies to this project's code.

Set `PORTFOLIO_URL` to change the return link (default `http://localhost:4322`). No uploads or personal-data collection. All dependencies and output are outside the UOC directory.
