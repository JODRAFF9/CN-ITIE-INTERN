# =============================================================================
# OpenRBE - Module Réseau v1.3
# Zoom automatique sur le noeud sélectionné — pas de mauve
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
              shiny::icon("diagram-project"),
              " Réseau de propriété effective"
            ),
            shiny::div(class = "network-filters",
              shiny::sliderInput(
                ns("max_companies"),
                "Nb max d'entreprises :",
                min = 5, max = 50, value = 20, step = 5, width = "220px"
              ),
              shiny::actionButton(
                ns("refresh_network"),
                label = "Rafraîchir",
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

          # Panneau info noeud sélectionné
          shiny::uiOutput(ns("node_info_panel")),

          visNetwork::visNetworkOutput(ns("network_graph"), height = "560px"),

          shiny::div(class = "network-info",
            shiny::icon("info-circle"),
            " Cliquez sur un noeud pour zoomer dessus et voir ses connexions.",
            " Molette pour zoomer. Double-clic pour recentrer."
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
      nd <- graph_data()

      visNetwork::visNetwork(nodes = nd$nodes, edges = nd$edges, width = "100%") |>
        visNetwork::visOptions(
          highlightNearest = list(
            enabled   = TRUE,
            degree    = 1,
            hover     = TRUE,
            labelOnly = FALSE,
            algorithm = "hierarchical"
          ),
          nodesIdSelection = list(
            enabled = TRUE,
            main    = "Sélectionner un noeud",
            style   = paste0(
              "width:220px;font-size:13px;",
              "border:1px solid #008C45;",
              "border-radius:4px;padding:4px;"
            )
          )
        ) |>
        # Groupe Entreprise : vert ITIE
        visNetwork::visGroups(
          groupname = "Entreprise",
          color = list(
            background = "#008C45",
            border     = "#005A2E",
            highlight  = list(background = "#F4C300", border = "#B89300")
          ),
          shape = "dot",
          size  = 22,
          font  = list(size = 13, bold = TRUE, color = "#1A1A1A")
        ) |>
        # Groupe Bénéficiaire : jaune ITIE
        visNetwork::visGroups(
          groupname = "Bénéficiaire",
          color = list(
            background = "#F4C300",
            border     = "#B89300",
            highlight  = list(background = "#D62D20", border = "#8B1A12")
          ),
          shape = "dot",
          size  = 14,
          font  = list(size = 11, color = "#1A1A1A")
        ) |>
        visNetwork::visPhysics(
          solver = "forceAtlas2Based",
          forceAtlas2Based = list(
            gravitationalConstant = -60,
            centralGravity        = 0.015,
            springLength          = 110,
            springConstant        = 0.08,
            avoidOverlap          = 0.6
          ),
          stabilization = list(enabled = TRUE, iterations = 250, fit = TRUE)
        ) |>
        visNetwork::visInteraction(
          navigationButtons = TRUE,
          tooltipDelay      = 80,
          zoomView          = TRUE,
          dragNodes         = TRUE,
          multiselect       = FALSE
        ) |>
        visNetwork::visLayout(randomSeed = 42) |>
        visNetwork::visLegend(
          useGroups = TRUE,
          position  = "right",
          width     = 0.14
        ) |>
        # Événement JS : zoom automatique sur le noeud cliqué
        visNetwork::visEvents(
          selectNode = "function(params) {
            if (params.nodes.length > 0) {
              var nodeId = params.nodes[0];
              this.focus(nodeId, {
                scale    : 1.6,
                animation: {
                  duration       : 700,
                  easingFunction : 'easeInOutQuad'
                }
              });
              Shiny.setInputValue(
                'network-selected_node', nodeId, {priority: 'event'}
              );
            }
          }",
          deselectNode = "function(params) {
            Shiny.setInputValue(
              'network-selected_node', null, {priority: 'event'}
            );
          }"
        ) |>
        visNetwork::visExport(
          type  = "png",
          name  = "openrbe_reseau",
          label = "Exporter PNG",
          style = paste0(
            "background:#008C45;color:white;",
            "padding:6px 14px;border-radius:4px;",
            "border:none;cursor:pointer;font-size:13px;"
          )
        )
    })

    # Panneau d'info du noeud sélectionné
    output$node_info_panel <- shiny::renderUI({
      node_id <- input$`network-selected_node`
      if (is.null(node_id) || identical(node_id, "null") ||
          identical(node_id, "NULL")) return(NULL)

      nd       <- graph_data()
      node_row <- nd$nodes[nd$nodes$id == node_id, ]
      if (nrow(node_row) == 0) return(NULL)

      is_company <- node_row$group == "Entreprise"
      icon_cls   <- if (is_company) "fas fa-building" else "fas fa-user"
      bg_color   <- if (is_company) "#E8F5EE" else "#FFF8E1"
      bd_color   <- if (is_company) "#008C45" else "#B89300"

      edges_sel  <- nd$edges[nd$edges$from == node_id |
                              nd$edges$to   == node_id, ]
      n_conn     <- nrow(edges_sel)
      conn_label <- if (is_company) {
        paste0(n_conn, " bénéficiaire(s) relié(s)")
      } else {
        paste0(n_conn, " entreprise(s) reliée(s)")
      }

      shiny::div(
        style = paste0(
          "background:", bg_color, ";",
          "border:1px solid ", bd_color, ";",
          "border-radius:8px;padding:12px 16px;margin-bottom:14px;",
          "display:flex;align-items:center;gap:14px;"
        ),
        shiny::div(
          style = paste0(
            "width:40px;height:40px;background:", bd_color, ";",
            "border-radius:50%;display:flex;align-items:center;",
            "justify-content:center;flex-shrink:0;"
          ),
          tags$i(class = icon_cls, style = "color:white;font-size:16px;")
        ),
        shiny::div(
          shiny::strong(
            as.character(node_row$title),
            style = "font-size:14px;display:block;color:#1A1A1A;"
          ),
          shiny::span(
            style = "font-size:12px;color:#555;",
            node_row$group, " — ", conn_label
          )
        )
      )
    })
  })
}