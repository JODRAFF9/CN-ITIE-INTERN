# =============================================================================
# OpenRBE - Module Tableau de bord
# ITIE Sénégal - modules/dashboard_module.R
# =============================================================================

dashboardUI <- function(id) {
  ns <- shiny::NS(id)
  
  shiny::tagList(
    # KPI Row
    shiny::div(class = "kpi-row",
      shiny::uiOutput(ns("kpi_companies")),
      shiny::uiOutput(ns("kpi_beneficiaries")),
      shiny::uiOutput(ns("kpi_avg")),
      shiny::uiOutput(ns("kpi_ppe")),
      shiny::uiOutput(ns("kpi_nationalities")),
      shiny::uiOutput(ns("kpi_countries"))
    ),
    
    # Graphiques row 1
    shiny::fluidRow(
      shiny::column(7,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("globe-africa"), " Répartition par nationalité"
          ),
          plotly::plotlyOutput(ns("nationality_chart"), height = "340px")
        )
      ),
      shiny::column(5,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("user-tie"), " Statut PPE"
          ),
          plotly::plotlyOutput(ns("ppe_pie_chart"), height = "340px")
        )
      )
    ),
    
    # Graphiques row 2
    shiny::fluidRow(
      shiny::column(6,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("map-marker-alt"), " Répartition régionale"
          ),
          highcharter::highchartOutput(ns("regional_chart"), height = "340px")
        )
      ),
      shiny::column(6,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("chart-bar"), " Distribution des participations (%)"
          ),
          plotly::plotlyOutput(ns("ownership_hist"), height = "340px")
        )
      )
    ),
    
    # Top 20 entreprises
    shiny::fluidRow(
      shiny::column(12,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("building"), " Top entreprises par nombre de bénéficiaires"
          ),
          shiny::div(class = "table-export-btns",
            shiny::downloadButton(ns("dl_top_excel"), "Excel",
                                  class = "btn-export btn-excel"),
            shiny::downloadButton(ns("dl_top_csv"), "CSV",
                                  class = "btn-export btn-csv")
          ),
          DT::dataTableOutput(ns("top_companies_table"))
        )
      )
    )
  )
}

dashboardServer <- function(id, filtered_data) {
  shiny::moduleServer(id, function(input, output, session) {
    
    # KPI Cards
    output$kpi_companies <- shiny::renderUI({
      kpi_card("fa-building", "Entreprises",
               fmt_number(get_total_companies(filtered_data())),
               color = "#008C45")
    })
    output$kpi_beneficiaries <- shiny::renderUI({
      kpi_card("fa-users", "Bénéficiaires effectifs",
               fmt_number(get_total_beneficiaries(filtered_data())),
               color = "#005A8E")
    })
    output$kpi_avg <- shiny::renderUI({
      kpi_card("fa-calculator", "Moy. bén./entreprise",
               fmt_number(get_average_beneficiaries(filtered_data())),
               color = "#6F42C1")
    })
    output$kpi_ppe <- shiny::renderUI({
      kpi_card("fa-user-tie", "Personnes Exposées Pol.",
               fmt_number(get_total_ppe(filtered_data())),
               color = "#D62D20")
    })
    output$kpi_nationalities <- shiny::renderUI({
      kpi_card("fa-flag", "Nationalités",
               fmt_number(get_total_nationalities(filtered_data())),
               color = "#F4C300")
    })
    output$kpi_countries <- shiny::renderUI({
      kpi_card("fa-globe", "Pays de résidence",
               fmt_number(get_total_residence_countries(filtered_data())),
               color = "#20B2AA")
    })
    
    # Graphiques
    output$nationality_chart <- plotly::renderPlotly({
      shiny::req(nrow(filtered_data()) > 0)
      make_nationality_chart(filtered_data())
    })
    
    output$ppe_pie_chart <- plotly::renderPlotly({
      shiny::req(nrow(filtered_data()) > 0)
      make_ppe_pie_chart(filtered_data())
    })
    
    output$regional_chart <- highcharter::renderHighchart({
      shiny::req(nrow(filtered_data()) > 0)
      make_regional_chart(filtered_data())
    })
    
    output$ownership_hist <- plotly::renderPlotly({
      shiny::req(nrow(filtered_data()) > 0)
      make_ownership_histogram(filtered_data())
    })
    
    # Top companies table
    top_data <- shiny::reactive({
      cs <- get_company_structure(filtered_data())
      cs[, .(
        "Entreprise"          = denomination_sociale,
        "Région"              = region,
        "Greffe"              = greffe,
        "Bénéficiaires"       = n_beneficiaires,
        "Part. moy. (%)"      = ifelse(is.nan(pct_moyen), "—", paste0(pct_moyen, "%")),
        "PPE"                 = n_ppe
      )]
    })
    
    output$top_companies_table <- DT::renderDataTable({
      DT::datatable(
        top_data(),
        options = list(
          pageLength = 10,
          scrollX    = TRUE,
          language   = list(
            url = "//cdn.datatables.net/plug-ins/1.10.25/i18n/French.json"
          ),
          dom        = "frtip"
        ),
        class     = "table table-striped table-hover",
        rownames  = FALSE,
        selection = "none"
      ) |>
        DT::formatStyle("Bénéficiaires",
                        background = DT::styleColorBar(range(top_data()$Bénéficiaires), "#008C4530"),
                        backgroundSize = "100% 90%",
                        backgroundRepeat = "no-repeat",
                        backgroundPosition = "center") |>
        DT::formatStyle("PPE",
                        color = DT::styleInterval(0, c("inherit", "#D62D20")),
                        fontWeight = DT::styleInterval(0, c("normal", "bold")))
    })
    
    # Exports
    output$dl_top_excel <- shiny::downloadHandler(
      filename = function() paste0("top_entreprises_", Sys.Date(), ".xlsx"),
      content  = function(file) {
        openxlsx::write.xlsx(as.data.frame(top_data()), file, overwrite = TRUE)
      }
    )
    output$dl_top_csv <- shiny::downloadHandler(
      filename = function() paste0("top_entreprises_", Sys.Date(), ".csv"),
      content  = function(file) {
        utils::write.csv(as.data.frame(top_data()), file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  })
}
