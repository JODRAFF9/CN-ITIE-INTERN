# =============================================================================
# OpenRBE - Module Réseau de propriété
# ITIE Sénégal - modules/network_module.R
# =============================================================================

networkUI <- function(id) {
  ns <- shiny::NS(id)
  
  shiny::tagList(
    shiny::fluidRow(
      shiny::column(12,
        shiny::div(class = "chart-card",
          shiny::div(class = "network-controls",
            shiny::div(class = "chart-title",
              shiny::icon("project-diagram"),
              " Réseau de propriété effective"
            ),
            shiny::div(class = "network-filters",
              shiny::sliderInput(
                ns("max_companies"),
                "Nombre max d'entreprises affichées:",
                min   = 5,
                max   = 50,
                value = 20,
                step  = 5,
                width = "250px"
              ),
              shiny::actionButton(
                ns("refresh_network"),
                label = "Rafraîchir le graphe",
                icon  = shiny::icon("sync"),
                class = "btn-itie"
              )
            )
          ),
          shiny::div(class = "network-legend",
            shiny::span(class = "legend-dot legend-company"),
            " Entreprise  ",
            shiny::span(class = "legend-dot legend-ben"),
            " Bénéficiaire"
          ),
          visNetwork::visNetworkOutput(ns("network_graph"), height = "550px"),
          shiny::div(class = "network-info",
            shiny::p(
              shiny::icon("info-circle"),
              " Cliquez sur un nœud pour le mettre en surbrillance. ",
              "Utilisez la molette pour zoomer. Double-clic pour centrer."
            )
          )
        )
      )
    )
  )
}

networkServer <- function(id, filtered_data) {
  shiny::moduleServer(id, function(input, output, session) {
    
    graph_data <- shiny::eventReactive(
      list(input$refresh_network, filtered_data()),
      {
        shiny::req(nrow(filtered_data()) > 0)
        make_network_graph(filtered_data(), max_companies = input$max_companies)
      },
      ignoreNULL = FALSE
    )
    
    output$network_graph <- visNetwork::renderVisNetwork({
      shiny::req(graph_data())
      
      net_data <- graph_data()
      
      visNetwork::visNetwork(
        nodes = net_data$nodes,
        edges = net_data$edges,
        width = "100%"
      ) |>
        visNetwork::visOptions(
          highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE),
          nodesIdSelection = list(enabled = TRUE, main = "Sélectionner un nœud"),
          selectedBy       = list(variable = "group", main = "Filtrer par type")
        ) |>
        visNetwork::visLayout(randomSeed = 42) |>
        visNetwork::visPhysics(
          solver     = "forceAtlas2Based",
          forceAtlas2Based = list(
            gravitationalConstant = -80,
            centralGravity        = 0.01,
            springLength          = 100,
            springConstant        = 0.08,
            avoidOverlap          = 0.5
          ),
          stabilization = list(
            enabled   = TRUE,
            iterations = 200
          )
        ) |>
        visNetwork::visInteraction(
          navigationButtons = TRUE,
          tooltipDelay      = 100,
          zoomView          = TRUE
        ) |>
        visNetwork::visLegend(
          useGroups = TRUE,
          position  = "right",
          width     = 0.15
        ) |>
        visNetwork::visGroups(
          groupname = "Entreprise",
          color     = list(background = "#008C45", border = "#005A2E"),
          shape     = "dot",
          size      = 20,
          font      = list(size = 13, bold = TRUE)
        ) |>
        visNetwork::visGroups(
          groupname = "Bénéficiaire",
          color     = list(background = "#F4C300", border = "#B89300"),
          shape     = "dot",
          size      = 12,
          font      = list(size = 11)
        ) |>
        visNetwork::visExport(
          type     = "png",
          name     = "openrbe_reseau",
          label    = "Exporter PNG",
          style    = "background:#008C45;color:white;padding:6px 12px;border-radius:4px;border:none;cursor:pointer;"
        )
    })
  })
}
