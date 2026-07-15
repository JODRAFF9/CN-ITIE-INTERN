# =============================================================================
# OpenRBE - Module Analyse PPE — Informations exhaustives, NA gérés
# ITIE Sénégal - modules/ppe_module.R  v1.2
# =============================================================================

ppeUI <- function(id) {
  ns <- shiny::NS(id)

  shiny::tagList(

    # KPIs PPE
    shiny::div(class = "kpi-row",
      shiny::uiOutput(ns("kpi_total_ppe")),
      shiny::uiOutput(ns("kpi_companies_ppe")),
      shiny::uiOutput(ns("kpi_nat_ppe")),
      shiny::uiOutput(ns("kpi_pays_ppe")),
      shiny::uiOutput(ns("kpi_pct_moy_ppe"))
    ),

    # Graphiques ligne 1
    shiny::fluidRow(
      shiny::column(6,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("flag"), " PPE par nationalité"),
          plotly::plotlyOutput(ns("ppe_nat_chart"), height = "300px")
        )
      ),
      shiny::column(6,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("map-marker-alt"), " PPE par région"),
          plotly::plotlyOutput(ns("ppe_region_chart"), height = "300px")
        )
      )
    ),

    # Distribution des participations
    shiny::fluidRow(
      shiny::column(12,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("percent"), " Distribution des participations des PPE"),
          plotly::plotlyOutput(ns("ppe_pct_chart"), height = "260px")
        )
      )
    ),

    # Message si aucun PPE
    shiny::uiOutput(ns("no_ppe_msg")),

    # Tableau PPE complet
    shiny::fluidRow(
      shiny::column(12,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("user-tie"),
            " Liste complète des Personnes Politiquement Exposées (PPE)"
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

    # ── KPIs ──────────────────────────────────────────────────────────────────
    output$kpi_total_ppe <- shiny::renderUI({
      kpi_card("fa-user-shield", "Total PPE",
               fmt_number(nrow(ppe_data())), color = "#D62D20")
    })

    output$kpi_companies_ppe <- shiny::renderUI({
      n <- data.table::uniqueN(ppe_data()$denomination_sociale)
      kpi_card("fa-building", "Entreprises concernées",
               fmt_number(n), color = "#F4C300")
    })

    output$kpi_nat_ppe <- shiny::renderUI({
      n <- data.table::uniqueN(
        ppe_data()$nationalite[!is.na(ppe_data()$nationalite)])
      kpi_card("fa-flag", "Nationalités PPE",
               fmt_number(n), color = "#008C45")
    })

    output$kpi_pays_ppe <- shiny::renderUI({
      n <- data.table::uniqueN(
        ppe_data()$pays_residence[!is.na(ppe_data()$pays_residence)])
      kpi_card("fa-globe", "Pays résidence PPE",
               fmt_number(n), color = "#005A8E")
    })

    output$kpi_pct_moy_ppe <- shiny::renderUI({
      moy <- mean(ppe_data()$pct_action_direct, na.rm = TRUE)
      val <- if (is.nan(moy) || is.na(moy)) "—" else paste0(round(moy, 1), "%")
      kpi_card("fa-percent", "Part. moy. des PPE",
               val, color = "#6F42C1")
    })

    # ── Message aucun PPE ─────────────────────────────────────────────────────
    output$no_ppe_msg <- shiny::renderUI({
      if (nrow(ppe_data()) == 0) {
        shiny::div(
          class = "chart-card",
          style = "text-align:center;padding:32px;color:#6C757D;",
          tags$i(class = "fas fa-info-circle fa-2x",
                 style = "display:block;margin-bottom:10px;color:#F4C300;"),
          tags$strong("Aucun PPE dans la sélection actuelle."),
          tags$p("Modifiez les filtres pour voir les PPE.")
        )
      }
    })

    # ── Graphique PPE par nationalité ─────────────────────────────────────────
    output$ppe_nat_chart <- plotly::renderPlotly({
      dt <- ppe_data()
      if (nrow(dt) == 0) {
        return(plotly::plot_ly() |>
          plotly::layout(title = "Aucune donnée PPE",
                         paper_bgcolor = "white", plot_bgcolor = "white"))
      }
      dist <- dt[!is.na(nationalite), .N, by = nationalite]
      data.table::setorder(dist, -N)

      plotly::plot_ly(
        data = dist,
        x    = ~reorder(nationalite, N),
        y    = ~N,
        type = "bar",
        marker = list(color = "#D62D20",
                      line = list(color = "#8B1A12", width = 0.5)),
        hovertemplate = "<b>%{x}</b><br>PPE: %{y}<extra></extra>"
      ) |>
        plotly::layout(
          xaxis = list(title = "", tickfont = list(size = 11)),
          yaxis = list(title = "Nombre de PPE", gridcolor = "#f0f0f0"),
          plot_bgcolor  = "white",
          paper_bgcolor = "white",
          margin = list(l = 50, r = 10, t = 10, b = 80),
          font   = list(family = "Inter, Arial, sans-serif")
        )
    })

    # ── Graphique PPE par région ───────────────────────────────────────────────
    output$ppe_region_chart <- plotly::renderPlotly({
      dt <- ppe_data()
      if (nrow(dt) == 0) {
        return(plotly::plot_ly() |>
          plotly::layout(title = "Aucune donnée PPE",
                         paper_bgcolor = "white", plot_bgcolor = "white"))
      }
      dist <- dt[!is.na(region), .N, by = region]
      data.table::setorder(dist, -N)

      plotly::plot_ly(
        data = dist,
        x    = ~reorder(region, N),
        y    = ~N,
        type = "bar",
        marker = list(color = "#F4C300",
                      line = list(color = "#B89300", width = 0.5)),
        hovertemplate = "<b>%{x}</b><br>PPE: %{y}<extra></extra>"
      ) |>
        plotly::layout(
          xaxis = list(title = "", tickfont = list(size = 11)),
          yaxis = list(title = "Nombre de PPE", gridcolor = "#f0f0f0"),
          plot_bgcolor  = "white",
          paper_bgcolor = "white",
          margin = list(l = 50, r = 10, t = 10, b = 80),
          font   = list(family = "Inter, Arial, sans-serif")
        )
    })

    # ── Distribution des participations des PPE ────────────────────────────────
    output$ppe_pct_chart <- plotly::renderPlotly({
      dt  <- ppe_data()
      val <- dt$pct_action_direct[!is.na(dt$pct_action_direct)]
      if (length(val) == 0) {
        return(plotly::plot_ly() |>
          plotly::layout(title = "Participations non renseignées",
                         paper_bgcolor = "white", plot_bgcolor = "white"))
      }
      plotly::plot_ly(
        x    = val,
        type = "histogram",
        nbinsx = 15,
        marker = list(color = "#6F42C1",
                      line = list(color = "#4a2a8a", width = 0.5)),
        hovertemplate = "Participation: %{x}%<br>PPE: %{y}<extra></extra>"
      ) |>
        plotly::layout(
          xaxis = list(title = "% Action Direct", gridcolor = "#f0f0f0"),
          yaxis = list(title = "Nombre de PPE",   gridcolor = "#f0f0f0"),
          plot_bgcolor  = "white",
          paper_bgcolor = "white",
          margin = list(l = 50, r = 10, t = 10, b = 50),
          font   = list(family = "Inter, Arial, sans-serif")
        )
    })

    # ── Tableau PPE complet ───────────────────────────────────────────────────
    output$ppe_table <- DT::renderDataTable({
      dt <- ppe_data()
      if (nrow(dt) == 0) {
        return(DT::datatable(
          data.frame(Message = "Aucun PPE dans la sélection actuelle."),
          options = list(dom = "t"), rownames = FALSE
        ))
      }

      na_cell <- "<em style='color:#aaa;font-size:0.87em;'>Non renseigné</em>"
      na_fmt  <- function(x) {
        ifelse(is.na(x) | as.character(x) %in% c("NA",""),
               na_cell, as.character(x))
      }

      display <- data.frame(
        "Bénéficiaire"  = dt$prenom_nom,
        "Entreprise"    = dt$denomination_sociale,
        "Région"        = na_fmt(dt$region),
        "Nationalité"   = na_fmt(dt$nationalite),
        "Pays résidence" = na_fmt(dt$pays_residence),
        "% Action"      = ifelse(is.na(dt$pct_action_direct),
                                 na_cell, paste0(dt$pct_action_direct, "%")),
        "% Voix"        = ifelse(is.na(dt$pct_voix_direct),
                                 na_cell, paste0(dt$pct_voix_direct, "%")),
        "Fonction PPE"  = na_fmt(dt$fonction_ppe),
        "Nom PPE lié"   = na_fmt(dt$nom_ppe),
        check.names     = FALSE,
        stringsAsFactors = FALSE
      )

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
        rownames = FALSE,
        escape   = FALSE
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
