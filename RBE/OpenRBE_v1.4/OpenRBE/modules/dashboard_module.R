# =============================================================================
# OpenRBE - Module Tableau de bord  v1.3
# ITIE Sénégal - modules/dashboard_module.R
# Couleurs : vert ITIE, jaune ITIE, rouge ITIE, bleu marine — pas de mauve
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

    # Graphiques ligne 1
    shiny::fluidRow(
      shiny::column(7,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("globe-africa"), " Répartition par nationalité"),
          plotly::plotlyOutput(ns("nationality_chart"), height = "340px")
        )
      ),
      shiny::column(5,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("user-tie"), " Statut PPE"),
          plotly::plotlyOutput(ns("ppe_pie_chart"), height = "340px")
        )
      )
    ),

    # Graphiques ligne 2
    shiny::fluidRow(
      shiny::column(6,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("map-marker-alt"), " Répartition régionale"),
          highcharter::highchartOutput(ns("regional_chart"), height = "340px")
        )
      ),
      shiny::column(6,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("chart-bar"), " Distribution des participations (%)"),
          plotly::plotlyOutput(ns("ownership_hist"), height = "340px")
        )
      )
    ),

    # Top entreprises
    shiny::fluidRow(
      shiny::column(12,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("building"), " Top entreprises par nombre de bénéficiaires"),
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

    # KPI Cards — palette ITIE uniquement (vert, bleu marine, rouge, jaune, teal)
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
               color = "#1A6B3C")
    })
    output$kpi_ppe <- shiny::renderUI({
      kpi_card("fa-user-tie", "Pers. Expos. Pol.",
               fmt_number(get_total_ppe(filtered_data())),
               color = "#D62D20")
    })
    output$kpi_nationalities <- shiny::renderUI({
      kpi_card("fa-flag", "Nationalités",
               fmt_number(get_total_nationalities(filtered_data())),
               color = "#B89300")
    })
    output$kpi_countries <- shiny::renderUI({
      kpi_card("fa-globe", "Pays de résidence",
               fmt_number(get_total_residence_countries(filtered_data())),
               color = "#005A8E")
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

    # Tableau Top entreprises
    top_data <- shiny::reactive({
      cs <- get_company_structure(filtered_data())
      data.frame(
        "Entreprise"     = cs$denomination_sociale,
        "Région"         = ifelse(is.na(cs$region), "Non renseigné", cs$region),
        "Greffe"         = ifelse(is.na(cs$greffe), "Non renseigné", cs$greffe),
        "Bénéficiaires"  = cs$n_beneficiaires,
        "Part. moy. (%)" = ifelse(is.nan(cs$pct_moyen) | is.na(cs$pct_moyen),
                                  "Non renseigné", paste0(cs$pct_moyen, "%")),
        "PPE"            = cs$n_ppe,
        check.names = FALSE, stringsAsFactors = FALSE
      )
    })

    output$top_companies_table <- DT::renderDataTable({
      DT::datatable(
        top_data(),
        options = list(
          pageLength = 10, scrollX = TRUE,
          language   = list(
            url = "//cdn.datatables.net/plug-ins/1.10.25/i18n/French.json"),
          dom = "frtip"
        ),
        class    = "table table-striped table-hover",
        rownames = FALSE, selection = "none"
      ) |>
        DT::formatStyle("PPE",
          color      = DT::styleInterval(0, c("inherit", "#D62D20")),
          fontWeight = DT::styleInterval(0, c("normal", "bold")))
    })

    # Exports
    output$dl_top_excel <- shiny::downloadHandler(
      filename = function() paste0("top_entreprises_", Sys.Date(), ".xlsx"),
      content  = function(file) {
        openxlsx::write.xlsx(top_data(), file, overwrite = TRUE)
      }
    )
    output$dl_top_csv <- shiny::downloadHandler(
      filename = function() paste0("top_entreprises_", Sys.Date(), ".csv"),
      content  = function(file) {
        utils::write.csv(top_data(), file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  })
}