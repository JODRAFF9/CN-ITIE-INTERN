# =============================================================================
# OpenRBE - Module Recherche Entreprise
# ITIE Sénégal - modules/search_module.R
# =============================================================================

searchUI <- function(id) {
  ns <- shiny::NS(id)
  
  shiny::tagList(
    shiny::fluidRow(
      shiny::column(12,
        shiny::div(class = "search-hero",
          shiny::div(class = "search-hero-inner",
            shiny::h3(
              shiny::icon("search"), " Recherche d'entreprise",
              class = "search-title"
            ),
            shiny::p("Sélectionnez une entreprise pour consulter sa fiche bénéficiaire",
                     class = "search-subtitle"),
            shiny::selectizeInput(
              ns("company_select"),
              label   = NULL,
              choices = NULL,
              options = list(
                placeholder     = "Tapez le nom d'une entreprise...",
                maxOptions      = 500,
                searchField     = "label",
                render          = list(option = I(
                  'function(item, escape) {
                    return "<div class=\'search-option\'>" + escape(item.label) + "</div>";
                  }'
                ))
              ),
              width = "100%"
            )
          )
        )
      )
    ),
    
    # Fiche entreprise (masquée par défaut)
    shiny::uiOutput(ns("company_card")),
    
    # Tableau bénéficiaires
    shiny::uiOutput(ns("beneficiaries_panel"))
  )
}

searchServer <- function(id, rbe_data) {
  shiny::moduleServer(id, function(input, output, session) {
    
    # Mettre à jour la liste des entreprises
    shiny::observe({
      companies <- sort(unique(rbe_data()$denomination_sociale))
      shiny::updateSelectizeInput(
        session,
        "company_select",
        choices  = companies,
        selected = NULL,
        server   = TRUE
      )
    })
    
    # Données de l'entreprise sélectionnée
    selected_company <- shiny::reactive({
      shiny::req(input$company_select)
      rbe_data()[denomination_sociale == input$company_select]
    })
    
    # Fiche entreprise
    output$company_card <- shiny::renderUI({
      shiny::req(input$company_select)
      dt <- selected_company()
      shiny::req(nrow(dt) > 0)
      
      n_ben  <- nrow(dt)
      n_ppe  <- sum(dt$est_ppe_bool, na.rm = TRUE)
      region <- dt$region[1]
      greffe <- dt$greffe[1]
      
      shiny::div(class = "company-card",
        shiny::div(class = "company-card-header",
          shiny::div(class = "company-card-icon",
            shiny::icon("building")
          ),
          shiny::div(class = "company-card-title",
            shiny::h4(input$company_select),
            shiny::p(
              shiny::span(class = "badge-region", region),
              if (!is.na(greffe) && greffe != "NA")
                shiny::span(class = "badge-greffe", paste0("Greffe: ", greffe))
            )
          )
        ),
        shiny::div(class = "company-stats",
          shiny::div(class = "company-stat",
            shiny::span(class = "company-stat-value", n_ben),
            shiny::span(class = "company-stat-label", "Bénéficiaire(s)")
          ),
          shiny::div(class = "company-stat",
            shiny::span(
              class = ifelse(n_ppe > 0, "company-stat-value ppe-alert", "company-stat-value"),
              n_ppe
            ),
            shiny::span(class = "company-stat-label", "PPE")
          ),
          shiny::div(class = "company-stat",
            shiny::span(class = "company-stat-value",
                        ifelse(is.na(mean(dt$pct_action_direct, na.rm = TRUE)), "—",
                               paste0(round(mean(dt$pct_action_direct, na.rm = TRUE), 1), "%"))
            ),
            shiny::span(class = "company-stat-label", "Part. moy.")
          )
        )
      )
    })
    
    # Tableau bénéficiaires
    output$beneficiaries_panel <- shiny::renderUI({
      shiny::req(input$company_select, nrow(selected_company()) > 0)
      
      shiny::div(class = "chart-card",
        shiny::div(class = "chart-title",
          shiny::icon("users"), " Bénéficiaires effectifs"
        ),
        shiny::div(class = "table-export-btns",
          shiny::downloadButton(
            session$ns("dl_bens_excel"), "Excel",
            class = "btn-export btn-excel"
          ),
          shiny::downloadButton(
            session$ns("dl_bens_csv"), "CSV",
            class = "btn-export btn-csv"
          )
        ),
        DT::dataTableOutput(session$ns("bens_table"))
      )
    })
    
    output$bens_table <- DT::renderDataTable({
      shiny::req(input$company_select)
      dt <- selected_company()
      shiny::req(nrow(dt) > 0)
      
      display <- dt[, .(
        "Bénéficiaire"      = prenom_nom,
        "Nationalité"       = nationalite,
        "Pays résidence"    = pays_residence,
        "% Action Direct"   = ifelse(is.na(pct_action_direct), "—",
                                      paste0(pct_action_direct, "%")),
        "% Voix Direct"     = ifelse(is.na(pct_voix_direct), "—",
                                      paste0(pct_voix_direct, "%")),
        "PPE"               = ifelse(est_ppe_bool, "✔ PPE", ""),
        "Fonction PPE"      = ifelse(is.na(fonction_ppe) | fonction_ppe %in% c("0","NA"),
                                      "—", as.character(fonction_ppe)),
        "Nom PPE"           = ifelse(is.na(nom_ppe), "—", nom_ppe),
        "Date acquisition"  = format(date_acquisition, "%d/%m/%Y")
      )]
      
      DT::datatable(
        display,
        options  = list(
          pageLength = 25,
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
        DT::formatStyle("PPE",
                        color      = "#D62D20",
                        fontWeight = "bold")
    })
    
    # Exports bénéficiaires
    output$dl_bens_excel <- shiny::downloadHandler(
      filename = function() paste0("beneficiaires_", gsub(" ", "_", input$company_select),
                                    "_", Sys.Date(), ".xlsx"),
      content  = function(file) {
        openxlsx::write.xlsx(as.data.frame(selected_company()), file, overwrite = TRUE)
      }
    )
    output$dl_bens_csv <- shiny::downloadHandler(
      filename = function() paste0("beneficiaires_", gsub(" ", "_", input$company_select),
                                    "_", Sys.Date(), ".csv"),
      content  = function(file) {
        utils::write.csv(as.data.frame(selected_company()), file,
                         row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  })
}
