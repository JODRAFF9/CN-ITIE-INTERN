# =============================================================================
# OpenRBE - Module Recherche Entreprise — Fiche exhaustive + NA gérés
# ITIE Sénégal - modules/search_module.R  v1.2
# =============================================================================

searchUI <- function(id) {
  ns <- shiny::NS(id)

  shiny::tagList(

    shiny::fluidRow(
      shiny::column(12,
        shiny::div(class = "search-hero",
          shiny::div(class = "search-hero-inner",
            tags$h3(class = "search-title",
              tags$i(class = "fas fa-search"), " Recherche d'entreprise"),
            tags$p(class = "search-subtitle",
              "Tapez les premiers caractères du nom pour filtrer la liste.",
              " Les entreprises suggérées sont issues de la base RBE."),
            shiny::selectizeInput(
              ns("company_select"),
              label   = NULL,
              choices = NULL,
              options = list(
                placeholder      = "Rechercher une entreprise...",
                maxOptions       = 400,
                maxItems         = 1,
                searchField      = "value",
                closeAfterSelect = TRUE,
                render = list(
                  option = I('function(item,escape){
                    return "<div style=\'padding:6px 10px;font-size:13px;\'>"
                      + escape(item.value) + "</div>";
                  }'),
                  item = I('function(item,escape){
                    return "<div>" + escape(item.value) + "</div>";
                  }')
                )
              ),
              width = "100%"
            )
          )
        )
      )
    ),

    shiny::uiOutput(ns("company_card")),
    shiny::uiOutput(ns("beneficiaries_panel"))
  )
}

searchServer <- function(id, rbe_data) {
  shiny::moduleServer(id, function(input, output, session) {

    # Charger toutes les entreprises dans selectize (server-side = performance)
    shiny::observe({
      companies <- sort(unique(rbe_data()$denomination_sociale))
      shiny::updateSelectizeInput(
        session, "company_select",
        choices  = companies,
        selected = character(0),
        server   = TRUE
      )
    })

    selected_company <- shiny::reactive({
      shiny::req(input$company_select, nchar(input$company_select) > 0)
      rbe_data()[denomination_sociale == input$company_select]
    })

    # ── Fiche entreprise ───────────────────────────────────────────────────
    output$company_card <- shiny::renderUI({
      shiny::req(input$company_select, nchar(input$company_select) > 0)
      dt <- selected_company()
      shiny::req(nrow(dt) > 0)

      n_ben      <- nrow(dt)
      n_ppe      <- sum(dt$est_ppe_bool, na.rm = TRUE)
      region_val <- dt$region[1]
      greffe_val <- dt$greffe[1]
      pct_moy    <- mean(dt$pct_action_direct, na.rm = TRUE)
      pct_med    <- median(dt$pct_action_direct, na.rm = TRUE)
      nat_list   <- unique(dt$nationalite[!is.na(dt$nationalite)])
      pays_list  <- unique(dt$pays_residence[!is.na(dt$pays_residence)])
      date_min   <- suppressWarnings(min(dt$date_acquisition, na.rm = TRUE))
      date_max   <- suppressWarnings(max(dt$date_acquisition, na.rm = TRUE))
      annees     <- unique(dt$annee_acquisition[!is.na(dt$annee_acquisition)])

      non_rens <- tags$em("Non renseigné", style = "color:#999;font-size:0.88em;")

      shiny::div(class = "company-card",

        # En-tête
        shiny::div(class = "company-card-header",
          shiny::div(class = "company-card-icon",
            tags$i(class = "fas fa-building")),
          shiny::div(class = "company-card-title",
            tags$h4(input$company_select),
            tags$p(
              if (!is.na(region_val))
                tags$span(class = "badge-region", region_val),
              if (!is.na(greffe_val))
                tags$span(class = "badge-greffe", paste0("Greffe : ", greffe_val))
            )
          )
        ),

        # KPI Stats
        shiny::div(class = "company-stats",
          shiny::div(class = "company-stat",
            tags$span(class = "company-stat-value", n_ben),
            tags$span(class = "company-stat-label", "Bénéficiaire(s)")),
          shiny::div(class = "company-stat",
            tags$span(
              class = if (n_ppe > 0) "company-stat-value ppe-alert" else "company-stat-value",
              n_ppe),
            tags$span(class = "company-stat-label", "PPE")),
          shiny::div(class = "company-stat",
            tags$span(class = "company-stat-value",
              if (is.nan(pct_moy) || is.na(pct_moy)) "—"
              else paste0(round(pct_moy, 1), "%")),
            tags$span(class = "company-stat-label", "Part. moyenne")),
          shiny::div(class = "company-stat",
            tags$span(class = "company-stat-value",
              if (is.nan(pct_med) || is.na(pct_med)) "—"
              else paste0(round(pct_med, 1), "%")),
            tags$span(class = "company-stat-label", "Part. médiane"))
        ),

        # Détails complémentaires
        shiny::div(
          style = paste0("padding:12px 24px 16px;",
                         "display:grid;grid-template-columns:1fr 1fr;",
                         "gap:10px 24px;font-size:13px;",
                         "border-top:1px solid #e9ecef;"),

          shiny::div(
            tags$b(style = "color:#555;",
              tags$i(class = "fas fa-flag", style = "margin-right:5px;color:#008C45;"),
              "Nationalité(s) :"),
            tags$div(style = "margin-top:3px;",
              if (length(nat_list) == 0) non_rens
              else paste(nat_list, collapse = " • "))
          ),

          shiny::div(
            tags$b(style = "color:#555;",
              tags$i(class = "fas fa-globe", style = "margin-right:5px;color:#008C45;"),
              "Pays de résidence :"),
            tags$div(style = "margin-top:3px;",
              if (length(pays_list) == 0) non_rens
              else paste(pays_list, collapse = " • "))
          ),

          shiny::div(
            tags$b(style = "color:#555;",
              tags$i(class = "fas fa-calendar", style = "margin-right:5px;color:#008C45;"),
              "1ère déclaration :"),
            tags$div(style = "margin-top:3px;",
              if (is.na(date_min) || is.infinite(date_min)) non_rens
              else format(date_min, "%d/%m/%Y"))
          ),

          shiny::div(
            tags$b(style = "color:#555;",
              tags$i(class = "fas fa-clock", style = "margin-right:5px;color:#008C45;"),
              "Dernière mise à jour :"),
            tags$div(style = "margin-top:3px;",
              if (is.na(date_max) || is.infinite(date_max)) non_rens
              else format(date_max, "%d/%m/%Y"))
          ),

          shiny::div(
            tags$b(style = "color:#555;",
              tags$i(class = "fas fa-calendar-alt", style = "margin-right:5px;color:#008C45;"),
              "Année(s) de déclaration :"),
            tags$div(style = "margin-top:3px;",
              if (length(annees) == 0) non_rens
              else paste(sort(annees), collapse = ", "))
          ),

          if (n_ppe > 0) shiny::div(
            tags$b(style = "color:#D62D20;",
              tags$i(class = "fas fa-user-shield", style = "margin-right:5px;"),
              "PPE identifiés :"),
            tags$div(style = "margin-top:3px;color:#D62D20;font-weight:600;",
              paste(dt$prenom_nom[dt$est_ppe_bool == TRUE], collapse = " • "))
          )
        )
      )
    })

    # ── Tableau des bénéficiaires ──────────────────────────────────────────
    output$beneficiaries_panel <- shiny::renderUI({
      shiny::req(input$company_select, nchar(input$company_select) > 0,
                 nrow(selected_company()) > 0)

      shiny::div(class = "chart-card",
        shiny::div(class = "chart-title",
          tags$i(class = "fas fa-users"), " Bénéficiaires effectifs"),
        shiny::div(class = "table-export-btns",
          shiny::downloadButton(session$ns("dl_bens_excel"), "Excel",
                                class = "btn-export btn-excel"),
          shiny::downloadButton(session$ns("dl_bens_csv"), "CSV",
                                class = "btn-export btn-csv")
        ),
        DT::dataTableOutput(session$ns("bens_table"))
      )
    })

    output$bens_table <- DT::renderDataTable({
      shiny::req(input$company_select, nchar(input$company_select) > 0)
      dt <- selected_company()
      shiny::req(nrow(dt) > 0)

      na_html <- "<em style='color:#aaa;font-size:0.88em;'>Non renseigné</em>"
      na_fmt  <- function(x, sfx = "") {
        ifelse(is.na(x) | as.character(x) %in% c("NA",""),
               na_html,
               paste0(as.character(x), sfx))
      }

      display <- data.frame(
        "Bénéficiaire"    = dt$prenom_nom,
        "Nationalité"     = na_fmt(dt$nationalite),
        "Pays résidence"  = na_fmt(dt$pays_residence),
        "% Action Direct" = na_fmt(dt$pct_action_direct, "%"),
        "% Voix Direct"   = na_fmt(dt$pct_voix_direct, "%"),
        "PPE"             = ifelse(dt$est_ppe_bool,
          "<span style='color:#D62D20;font-weight:700'>&#10004; PPE</span>", ""),
        "Fonction PPE"    = na_fmt(
          ifelse(is.na(dt$fonction_ppe), NA_character_, as.character(dt$fonction_ppe))),
        "Nom PPE"         = na_fmt(dt$nom_ppe),
        "Date acquisition" = ifelse(is.na(dt$date_acquisition),
          na_html, format(dt$date_acquisition, "%d/%m/%Y")),
        check.names      = FALSE,
        stringsAsFactors = FALSE
      )

      DT::datatable(
        display,
        options  = list(
          pageLength = 25,
          scrollX    = TRUE,
          language   = list(
            url = "//cdn.datatables.net/plug-ins/1.10.25/i18n/French.json"
          ),
          dom        = "frtip",
          columnDefs = list(
            list(className = "dt-center", targets = c(3, 4, 5, 8))
          )
        ),
        class    = "table table-striped table-hover",
        rownames = FALSE,
        escape   = FALSE
      )
    })

    # Exports
    output$dl_bens_excel <- shiny::downloadHandler(
      filename = function() paste0("beneficiaires_",
        gsub("[^A-Za-z0-9]", "_", input$company_select), "_", Sys.Date(), ".xlsx"),
      content = function(file) {
        openxlsx::write.xlsx(as.data.frame(selected_company()), file, overwrite = TRUE)
      }
    )
    output$dl_bens_csv <- shiny::downloadHandler(
      filename = function() paste0("beneficiaires_",
        gsub("[^A-Za-z0-9]", "_", input$company_select), "_", Sys.Date(), ".csv"),
      content = function(file) {
        utils::write.csv(as.data.frame(selected_company()), file,
                         row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  })
}
