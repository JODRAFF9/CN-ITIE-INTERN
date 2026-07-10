# =============================================================================
# OpenRBE - Module Analyse PPE
# ITIE Sénégal - modules/ppe_module.R
# =============================================================================

ppeUI <- function(id) {
  ns <- shiny::NS(id)
  
  shiny::tagList(
    # KPIs PPE
    shiny::div(class = "kpi-row",
      shiny::uiOutput(ns("kpi_total_ppe")),
      shiny::uiOutput(ns("kpi_companies_ppe")),
      shiny::uiOutput(ns("kpi_nat_ppe"))
    ),
    
    # Graphique PPE par nationalité
    shiny::fluidRow(
      shiny::column(12,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("flag"), " Répartition des PPE par nationalité"
          ),
          plotly::plotlyOutput(ns("ppe_nat_chart"), height = "320px")
        )
      )
    ),
    
    # Tableau PPE
    shiny::fluidRow(
      shiny::column(12,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("user-tie"), " Liste des Personnes Politiquement Exposées"
          ),
          shiny::div(class = "table-export-btns",
            shiny::downloadButton(ns("dl_ppe_excel"), "Excel",
                                  class = "btn-export btn-excel"),
            shiny::downloadButton(ns("dl_ppe_csv"), "CSV",
                                  class = "btn-export btn-csv")
          ),
          DT::dataTableOutput(ns("ppe_table"))
        )
      )
    )
  )
}

ppeServer <- function(id, filtered_data) {
  shiny::moduleServer(id, function(input, output, session) {
    
    ppe_data <- shiny::reactive({
      get_ppe_summary(filtered_data())
    })
    
    # KPIs
    output$kpi_total_ppe <- shiny::renderUI({
      kpi_card("fa-user-shield", "Total PPE",
               fmt_number(nrow(ppe_data())),
               color = "#D62D20")
    })
    output$kpi_companies_ppe <- shiny::renderUI({
      n <- data.table::uniqueN(ppe_data()$denomination_sociale)
      kpi_card("fa-building", "Entreprises concernées",
               fmt_number(n), color = "#F4C300")
    })
    output$kpi_nat_ppe <- shiny::renderUI({
      n <- data.table::uniqueN(ppe_data()$nationalite[!is.na(ppe_data()$nationalite)])
      kpi_card("fa-globe", "Nationalités PPE",
               fmt_number(n), color = "#008C45")
    })
    
    # Graphique
    output$ppe_nat_chart <- plotly::renderPlotly({
      shiny::req(nrow(filtered_data()) > 0)
      make_ppe_nationality_chart(filtered_data())
    })
    
    # Tableau
    output$ppe_table <- DT::renderDataTable({
      shiny::req(nrow(ppe_data()) > 0)
      
      display <- ppe_data()[, .(
        "Bénéficiaire"     = prenom_nom,
        "Entreprise"       = denomination_sociale,
        "Fonction PPE"     = ifelse(is.na(fonction_ppe) | fonction_ppe %in% c("0","1","NA"),
                                    "—", as.character(fonction_ppe)),
        "Nom PPE"          = ifelse(is.na(nom_ppe), "—", nom_ppe),
        "Nationalité"      = nationalite,
        "Pays résidence"   = pays_residence,
        "% Action"         = ifelse(is.na(pct_action_direct), "—",
                                    paste0(pct_action_direct, "%")),
        "Région"           = region
      )]
      
      DT::datatable(
        display,
        options = list(
          pageLength = 15,
          scrollX    = TRUE,
          language   = list(
            url = "//cdn.datatables.net/plug-ins/1.10.25/i18n/French.json"
          ),
          dom = "frtip"
        ),
        class    = "table table-striped table-hover",
        rownames = FALSE
      ) |>
        DT::formatStyle(
          "Bénéficiaire",
          fontWeight = "bold",
          color      = "#D62D20"
        )
    })
    
    # Exports
    output$dl_ppe_excel <- shiny::downloadHandler(
      filename = function() paste0("ppe_openrbe_", Sys.Date(), ".xlsx"),
      content  = function(file) {
        openxlsx::write.xlsx(as.data.frame(ppe_data()), file, overwrite = TRUE)
      }
    )
    output$dl_ppe_csv <- shiny::downloadHandler(
      filename = function() paste0("ppe_openrbe_", Sys.Date(), ".csv"),
      content  = function(file) {
        utils::write.csv(as.data.frame(ppe_data()), file,
                         row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  })
}
