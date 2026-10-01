source("bootstrap.R"); source("R/markov.R")
library(shiny)
colors<-c(A="#40d9dd",B="#b8f277",C="#be9cff",T="#ffa66b")
plot_theme<-function() par(bg="#101925",fg="#d0deeb",col.axis="#9daec0",col.lab="#d0deeb",col.main="#edf2f7",mar=c(4,4,2,1))
ui<-fluidPage(theme=bslib::bs_theme(version=5,bg="#080c12",fg="#edf2f7",primary="#40d9dd"),
  tags$head(tags$link(rel="stylesheet",href="style.css")),div(class="app-shell",
    div(class="app-nav",uiOutput("back_link"),span(class="signature","CARLOS RAMÍREZ MARTÍN / R + SIMULATION")),
    div(class="hero-copy",p(class="eyebrow","02 / MOBILITY MARKOV SIMULATOR"),uiOutput("title"),uiOutput("intro")),
    div(class="workspace",div(class="controls",h3("Escenario / Scenario"),
      selectInput("language","Idioma / Language",c("Español"="es","English"="en")),
      selectInput("mode","Modelo / Model",c("Movilidad / Mobility"="mobility","Avería absorbente / Absorbing failure"="absorbing","Mantenimiento / Maintenance"="maintenance"),selected="maintenance"),
      sliderInput("horizon","Transiciones / Transitions",min=1,max=150,value=40),
      sliderInput("step","Inspeccionar transición / Inspect transition",min=0,max=40,value=40,animate=animationOptions(interval=200,loop=FALSE)),
      numericInput("initial_a","Bicicletas A / Bicycles A",500,min=0,max=100000,step=1),
      numericInput("initial_b","Bicicletas B / Bicycles B",500,min=0,max=100000,step=1),
      numericInput("initial_c","Bicicletas C / Bicycles C",500,min=0,max=100000,step=1),
      sliderInput("failure","Prob. avería / Failure probability",min=0,max=1,value=.05,step=.01),
      sliderInput("repair","Prob. reparación / Repair probability",min=0,max=1,value=.25,step=.01),
      selectInput("return_station","Retorno / Return",c("A","B","C")),
      tags$details(tags$summary("Matriz de movilidad / Mobility matrix"),p(class="note","C = 1 − A − B"),
        numericInput("aa","A → A",.4,min=0,max=1,step=.01),numericInput("ab","A → B",.2,min=0,max=1,step=.01),
        numericInput("ba","B → A",.5,min=0,max=1,step=.01),numericInput("bb","B → B",.3,min=0,max=1,step=.01),
        numericInput("ca","C → A",.43,min=0,max=1,step=.01),numericInput("cb","C → B",.37,min=0,max=1,step=.01)),
      tags$details(tags$summary("Costes por evento / Event costs"),numericInput("trip_cost","Viaje / Trip (€)",.5,min=0,step=.1),numericInput("failure_cost","Avería / Failure (€)",50,min=0,step=1),numericInput("repair_cost","Reparación / Repair (€)",10,min=0,step=1)),
      checkboxInput("monte_carlo","Mostrar Monte Carlo / Show Monte Carlo",TRUE),
      downloadButton("download","Exportar / Export")),
    div(class="content",uiOutput("stats"),uiOutput("assumptions"),
      div(class="plot-grid",div(class="panel",h3("Red de estados / State network"),plotOutput("network",height=350)),
        div(class="panel",h3("Flota en esta transición / Fleet at this transition"),plotOutput("fleet",height=350))),
      div(class="panel",h3("Evolución / Evolution"),plotOutput("evolution",height=380)),
      div(class="plot-grid",div(class="panel",h3("Matriz / Matrix"),tableOutput("matrix")),div(class="panel",h3("Largo plazo / Long run"),tableOutput("stationary"),uiOutput("stationary_note"))),
      div(class="panel",h3("Comparar políticas / Compare policies"),tableOutput("comparison"),uiOutput("cost_note")))),
    p(class="footer-note","Origen académico · UOC / Simulation under explicit assumptions · Not observed operational performance")))

server<-function(input,output,session) {
  tr<-function(es,en) if(input$language=="en") en else es
  output$back_link<-renderUI(a(href=paste0(sub("/$","",Sys.getenv("PORTFOLIO_URL","http://localhost:4322")),"/",input$language,"/projects/mobility-markov-simulator/"),class="portfolio-back","← Portfolio / Carlos Ramírez Martín"))
  observeEvent(session$clientData$url_search,{query<-parseQueryString(session$clientData$url_search);if(!is.null(query$lang) && query$lang %in% c("es","en")) updateSelectInput(session,"language",selected=query$lang)},once=TRUE,ignoreNULL=FALSE)
  output$title<-renderUI(h1(tr("Una flota. Muchos futuros.","One fleet. Many futures.")))
  output$intro<-renderUI(p(class="lead",tr("Explora cómo los desplazamientos, las averías y las reparaciones cambian la disponibilidad de una flota. Compara la expectativa matemática con una simulación y descubre qué supuestos sostienen cada resultado.","Explore how trips, failures and repairs change fleet availability. Compare mathematical expectations with a simulation and discover the assumptions behind each result.")))
  observeEvent(input$horizon,updateSliderInput(session,"step",max=input$horizon,value=min(input$step,input$horizon)),ignoreInit=TRUE)
  base<-reactive({req(input$aa,input$ab,input$ba,input$bb,input$ca,input$cb)
    p<-base::matrix(c(input$aa,input$ab,1-input$aa-input$ab,input$ba,input$bb,1-input$ba-input$bb,input$ca,input$cb,1-input$ca-input$cb),3,byrow=TRUE,dimnames=list(c("A","B","C"),c("A","B","C")))
    tryCatch({validate_transition(p);p},error=function(e) validate(need(FALSE,tr("Matriz inválida: las probabilidades de cada fila deben estar entre 0 y 1 y sumar 1.","Invalid matrix: probabilities in each row must be between 0 and 1 and sum to 1."))))})
  matrix<-reactive(scenario_transition(base(),input$mode,input$failure,input$repair,input$return_station))
  initial<-reactive({a<-c(input$initial_a,input$initial_b,input$initial_c);validate(need(all(is.finite(a)) && all(a>=0) && all(a==floor(a)) && sum(a)>0 && sum(a)<=300000,tr("Introduce una flota entera y positiva, de hasta 300.000 bicicletas.","Enter a positive whole fleet of up to 300,000 bicycles.")));if(input$mode=="mobility") a else c(a,0)})
  trajectory<-reactive(evolve(matrix(),initial(),input$horizon))
  simulation<-reactive(simulate_fleet(matrix(),initial(),input$horizon,2026))
  selected<-reactive(min(input$step,input$horizon)+1)
  stat<-function(value,label) div(class="stat",strong(value),span(label))
  output$stats<-renderUI({path<-trajectory();row<-path[selected(),];active<-sum(row[setdiff(names(row),"T")]);cost<-scenario_costs(matrix(),path,input$trip_cost,input$failure_cost,input$repair_cost);
    div(class="stat-grid",stat(sprintf("%.1f%%",100*active/sum(initial())),tr("Disponibilidad esperada","Expected availability")),stat(input$horizon,tr("Horizonte de transiciones","Transition horizon")),stat(paste0(format(round(cost$total),big.mark=" ")," €"),tr("Coste esperado del horizonte","Expected horizon cost")))})
  output$assumptions<-renderUI(div(class="note warning",tr("SIMULACIÓN, NO DATOS REALES. Cada paso es una oportunidad de transición: las bicicletas activas hacen un viaje; las averiadas esperan o vuelven tras repararse. No equivale a una hora. Probabilidades constantes, sin límites de capacidad ni redistribución de flota.","SIMULATION, NOT REAL DATA. Each step is a transition opportunity: active bicycles make a trip; failed bicycles wait or return after repair. It is not an hour. Probabilities are constant, with no capacity limits or fleet rebalancing.")))
  output$network<-renderPlot({plot_theme();p<-matrix();n<-nrow(p);xy<-rbind(c(.18,.75),c(.82,.75),c(.5,.2),c(.86,.2))[seq_len(n),,drop=FALSE];par(mar=c(1,1,1,1));plot(NA,xlim=c(0,1),ylim=c(0,1),axes=FALSE,xlab="",ylab="")
    for(i in seq_len(n)) for(j in seq_len(n)) if(i!=j && p[i,j]>0) {
      from<-xy[i,];to<-xy[j,];v<-to-from;normal<-c(-v[2],v[1]);normal<-normal/sqrt(sum(normal^2));offset<-.02*normal
      arrows(from[1]+.12*v[1]+offset[1],from[2]+.12*v[2]+offset[2],to[1]-.12*v[1]+offset[1],to[2]-.12*v[2]+offset[2],length=.08,col=adjustcolor(colors[i],.6),lwd=1+3*p[i,j])
      mid<-(from+to)/2+.075*normal;text(mid[1],mid[2],sprintf("%.0f%%",100*p[i,j]),cex=.7,col=colors[i])
    }
    points(xy,pch=21,bg=colors[seq_len(n)],col="#edf2f7",cex=5);text(xy,labels=colnames(p),col="#080c12",font=2)
    text(xy[,1],xy[,2]+.13,sprintf("stay %.0f%%",100*diag(p)),cex=.7,col="#9daec0")})
  output$fleet<-renderPlot({plot_theme();row<-trajectory()[selected(),];barplot(row,col=colors[names(row)],border=NA,ylab=tr("Bicicletas esperadas","Expected bicycles"),ylim=c(0,max(1,row)*1.2));if(input$monte_carlo) points(seq_along(row)*1.2-.5,simulation()[selected(),],pch=4,col="#edf2f7",cex=1.3)})
  output$evolution<-renderPlot({plot_theme();path<-trajectory();matplot(0:input$horizon,path,type="l",lty=1,lwd=2,col=colors[colnames(path)],xlab=tr("Transiciones","Transitions"),ylab=tr("Bicicletas","Bicycles"));
    if(input$monte_carlo) matlines(0:input$horizon,simulation(),lty=3,lwd=1,col=adjustcolor(colors[colnames(path)],.7))
    abline(v=selected()-1,col="#9daec0",lty=2);legend("topright",legend=colnames(path),col=colors[colnames(path)],lty=1,bty="n",cex=.8)})
  output$matrix<-renderTable(matrix(),rownames=TRUE,digits=3)
  output$stationary<-renderTable({pi<-stationary_distribution(matrix());validate(need(!is.null(pi),tr("No hay una distribución estacionaria única.","There is no unique stationary distribution.")));data.frame(state=names(pi),probability=pi,expected_bicycles=pi*sum(initial()))},digits=3)
  output$stationary_note<-renderUI({p<-matrix();pi<-stationary_distribution(p);trips<-absorption_expectation(p);div(class="note",
    if(!is.null(trips)) p(tr(paste("Viajes esperados hasta avería desde A/B/C:",paste(round(trips,2),collapse=" / ")),paste("Expected trips until failure from A/B/C:",paste(round(trips,2),collapse=" / ")))),
    p(tr("Una distribución estacionaria es un equilibrio matemático; en cadenas periódicas la trayectoria puede no converger hacia él. La simulación Monte Carlo usa semilla 2026 y conserva exactamente el tamaño de la flota.","A stationary distribution is a mathematical equilibrium; trajectories in periodic chains may not converge to it. Monte Carlo uses seed 2026 and conserves fleet size exactly.")))})
  comparison<-reactive({validate(need(all(is.finite(c(input$trip_cost,input$failure_cost,input$repair_cost))) && min(input$trip_cost,input$failure_cost,input$repair_cost)>=0,tr("Los costes deben ser no negativos.","Costs must be nonnegative.")));compare_scenarios(base(),initial()[1:3],input$horizon,input$failure,input$repair,input$return_station,input$trip_cost,input$failure_cost,input$repair_cost)})
  output$comparison<-renderTable(comparison(),digits=3)
  output$cost_note<-renderUI(p(class="note",tr("Costes ilustrativos por viaje, entrada en avería y reparación, sin coste de compra ni ingresos. Los valores comparan escenarios bajo tus parámetros; no son una recomendación económica. Las líneas continuas muestran expectativas; las discontinuas, una realización Monte Carlo.","Illustrative costs per trip, failure entry and repair, excluding purchase costs and revenue. Values compare scenarios under your parameters; they are not financial recommendations. Solid lines show expectations; dotted lines show one Monte Carlo realization.")))
  output$download<-downloadHandler(filename=function() "markov-scenarios.json",content=function(file) {
    jsonlite::write_json(list(source="synthetic-scenario",seed=2026,unit="transition opportunity, not clock time",mode=input$mode,transition=matrix(),initial=initial(),trajectory=trajectory(),monte_carlo=simulation(),comparison=comparison(),stationary=stationary_distribution(matrix())),file,pretty=TRUE,auto_unbox=TRUE,digits=8)
  })
}
shinyApp(ui,server)
