validate_transition <- function(p) {
  if(!is.matrix(p) || !is.numeric(p) || nrow(p)!=ncol(p) || nrow(p)<2 ||
     any(!is.finite(p)) || any(p<0) || any(p>1) || any(abs(rowSums(p)-1)>1e-8))
    stop("Every transition row must contain probabilities in [0,1] summing to one.")
  invisible(TRUE)
}

base_transition <- function(alpha=3) {
  p <- matrix(c(.4,.2,.4,.5,.3,.2,.4+alpha/100,.4-alpha/100,.2),3,byrow=TRUE,
    dimnames=list(c("A","B","C"),c("A","B","C")))
  validate_transition(p); p
}

scenario_transition <- function(p=base_transition(), mode="mobility", failure=.05, repair=.25, return_station="A") {
  validate_transition(p)
  if(!mode %in% c("mobility","absorbing","maintenance")) stop("Unknown scenario.")
  if(mode=="mobility") return(p)
  if(any(!is.finite(c(failure,repair))) || min(failure,repair)<0 || max(failure,repair)>1) stop("Invalid failure or repair probability.")
  if(!return_station %in% colnames(p)) stop("Unknown return station.")
  q <- matrix(0,4,4,dimnames=list(c("A","B","C","T"),c("A","B","C","T")))
  q[1:3,1:3] <- (1-failure)*p; q[1:3,"T"] <- failure
  q["T","T"] <- 1
  if(mode=="maintenance") {q["T","T"]<-1-repair;q["T",return_station]<-repair}
  validate_transition(q); q
}

evolve <- function(p,initial,steps=40) {
  validate_transition(p)
  if(length(initial)!=nrow(p) || any(!is.finite(initial)) || any(initial<0) || sum(initial)<=0) stop("Invalid initial fleet.")
  if(length(steps)!=1 || !is.finite(steps) || steps<0 || steps!=as.integer(steps) || steps>500) stop("Steps must be an integer in [0,500].")
  out<-matrix(0,steps+1,nrow(p),dimnames=list(NULL,colnames(p)));out[1,]<-initial
  if(steps>0) for(i in seq_len(steps)) out[i+1,]<-out[i,] %*% p
  out
}

stationary_distribution <- function(p) {
  validate_transition(p)
  n<-nrow(p);a<-rbind(t(p)-diag(n),rep(1,n));b<-c(rep(0,n),1)
  if(qr(a)$rank<n) return(NULL)
  solution<-as.numeric(qr.solve(a,b));solution[abs(solution)<1e-10]<-0
  if(any(solution < -1e-8) || max(abs(as.numeric(solution %*% p)-solution))>1e-7) return(NULL)
  setNames(solution/sum(solution),colnames(p))
}

absorption_expectation <- function(p) {
  validate_transition(p)
  if(!"T" %in% colnames(p) || p["T","T"]!=1) return(NULL)
  e<-p[setdiff(rownames(p),"T"),setdiff(colnames(p),"T"),drop=FALSE]
  if(max(Mod(eigen(e)$values))>=1-1e-10) return(NULL)
  setNames(rowSums(solve(diag(nrow(e))-e)),rownames(e))
}

simulate_fleet <- function(p,initial,steps=40,seed=2026) {
  validate_transition(p)
  evolve(p,initial,steps)
  if(any(initial!=round(initial))) stop("Monte Carlo requires whole bicycles.")
  set.seed(seed)
  out<-matrix(0,steps+1,nrow(p),dimnames=list(NULL,colnames(p)));out[1,]<-initial
  if(steps>0) for(s in seq_len(steps)) {
    moved<-vapply(seq_len(nrow(p)),function(i) as.vector(rmultinom(1,out[s,i],p[i,])),numeric(nrow(p)))
    out[s+1,]<-rowSums(moved)
  }
  out
}

scenario_costs <- function(p,trajectory,trip_cost=.5,failure_cost=50,repair_cost=10) {
  if(any(!is.finite(c(trip_cost,failure_cost,repair_cost))) || min(trip_cost,failure_cost,repair_cost)<0) stop("Costs must be finite and nonnegative.")
  origins<-trajectory[-nrow(trajectory),,drop=FALSE]
  active<-setdiff(colnames(p),"T")
  # En cada paso las bicicletas activas viajan; las del taller esperan o salen reparadas.
  trips<-sum(origins[,active,drop=FALSE])
  failures<-if("T" %in% colnames(p)) sum(origins[,active,drop=FALSE] %*% p[active,"T",drop=FALSE]) else 0
  repairs<-if("T" %in% colnames(p)) sum(origins[,"T"])*(1-p["T","T"]) else 0
  list(trips=trips,failures=failures,repairs=repairs,total=trips*trip_cost+failures*failure_cost+repairs*repair_cost)
}

compare_scenarios <- function(p,initial,steps=40,failure=.05,repair=.25,return_station="A",trip_cost=.5,failure_cost=50,repair_cost=10) {
  modes<-c("mobility","absorbing","maintenance")
  rows<-lapply(modes,function(mode) {
    q<-scenario_transition(p,mode,failure,repair,return_station)
    start<-if(mode=="mobility") initial else c(initial,0)
    path<-evolve(q,start,steps);cost<-scenario_costs(q,path,trip_cost,failure_cost,repair_cost)
    data.frame(scenario=mode,availability=sum(path[nrow(path),setdiff(colnames(q),"T")])/sum(initial),
      total_cost=cost$total,expected_failures=cost$failures,expected_repairs=cost$repairs)
  })
  do.call(rbind,rows)
}
