# =============================================================================
# OpenRBE — Open Registre des Bénéficiaires Effectifs
# ITIE Sénégal | Version 1.1 — Onglets et filtres corrigés
# =============================================================================

suppressPackageStartupMessages({
  library(shiny)
  library(shinyWidgets)
  library(DT)
  library(plotly)
  library(highcharter)
  library(leaflet)
  library(visNetwork)
  library(data.table)
  library(readxl)
  library(openxlsx)
  library(stringr)
  library(htmltools)
})

source("R/load_data.R")
source("R/indicators.R")
source("R/charts.R")
source("R/helpers.R")
source("modules/dashboard_module.R")
source("modules/search_module.R")
source("modules/ppe_module.R")
source("modules/network_module.R")
source("modules/map_module.R")

RBE_DATA          <- load_rbe_data("data/rbe_data.xlsx")
ALL_REGIONS       <- sort(unique(RBE_DATA$region[!is.na(RBE_DATA$region)]))
ALL_NATIONALITIES <- sort(unique(RBE_DATA$nationalite[!is.na(RBE_DATA$nationalite)]))
ALL_PAYS          <- sort(unique(RBE_DATA$pays_residence[!is.na(RBE_DATA$pays_residence)]))
ALL_GREFFES       <- sort(unique(RBE_DATA$greffe[!is.na(RBE_DATA$greffe)]))

# =============================================================================
# UI
# =============================================================================
ui <- fluidPage(

  tags$head(
    tags$meta(charset = "utf-8"),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    tags$title("OpenRBE | ITIE Sénégal"),
    tags$link(rel = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap"),
    tags$link(rel = "stylesheet",
      href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"),
    tags$link(rel = "stylesheet", href = "css/styles.css"),
    tags$script(src = "js/custom.js")
  ),

  # ── HEADER ─────────────────────────────────────────────────────────────────
  tags$header(class = "main-header",
    tags$div(class = "header-inner",
      tags$div(class = "header-logo",
        tags$img(src = "img/logo_itie.png", alt = "Logo ITIE Sénégal", height = "56px")
      ),
      tags$div(class = "header-divider"),
      tags$div(class = "header-text",
        tags$h1(class = "header-title",
          tags$span(class = "title-open", "Open"),
          tags$span(class = "title-rbe",  "RBE")
        ),
        tags$p(class = "header-subtitle", "Portail de données - Registre des Bénéficiaires Effectifs"),
        tags$p(class = "header-tagline",
          "Plateforme nationale de consultation des bénéficiaires effectifs",
          " du secteur extractif au Sénégal")
      ),
      tags$div(class = "ms-auto",
        tags$div(class = "header-badge",
          tags$i(class = "fas fa-shield-halved"), " Données officielles ITIE")
      )
    )
  ),

  # ── CORPS : sidebar + contenu ─────────────────────────────────────────────
  fluidRow(

    # Sidebar filtres
    column(2,
      tags$div(class = "main-content", style = "padding-right:8px;",
        tags$div(class = "sidebar-panel",

          tags$div(class = "sidebar-title",
            tags$i(class = "fas fa-filter"), " Filtres"),

          tags$div(class = "filter-section",
            tags$div(class = "filter-label", "Région"),
            pickerInput("filter_region", NULL,
              choices = ALL_REGIONS, selected = character(0), multiple = TRUE,
              options = pickerOptions(actionsBox = TRUE,
                selectedTextFormat = "count > 1", countSelectedText = "{0} régions",
                noneSelectedText = "Toutes"),
              width = "100%")
          ),

          tags$div(class = "filter-section",
            tags$div(class = "filter-label", "Nationalité"),
            pickerInput("filter_nat", NULL,
              choices = ALL_NATIONALITIES, selected = character(0), multiple = TRUE,
              options = pickerOptions(actionsBox = TRUE, liveSearch = TRUE,
                selectedTextFormat = "count > 1", countSelectedText = "{0} nationalités",
                noneSelectedText = "Toutes", liveSearchPlaceholder = "Chercher..."),
              width = "100%")
          ),

          tags$div(class = "filter-section",
            tags$div(class = "filter-label", "Pays de résidence"),
            pickerInput("filter_pays", NULL,
              choices = ALL_PAYS, selected = character(0), multiple = TRUE,
              options = pickerOptions(actionsBox = TRUE, liveSearch = TRUE,
                selectedTextFormat = "count > 1", countSelectedText = "{0} pays",
                noneSelectedText = "Tous", liveSearchPlaceholder = "Chercher..."),
              width = "100%")
          ),

          tags$div(class = "filter-section",
            tags$div(class = "filter-label", "Greffe"),
            pickerInput("filter_greffe", NULL,
              choices = ALL_GREFFES, selected = character(0), multiple = TRUE,
              options = pickerOptions(noneSelectedText = "Tous"),
              width = "100%")
          ),

          tags$div(class = "filter-section",
            tags$div(class = "filter-label", "Statut PPE"),
            switchInput("filter_ppe", "PPE uniquement",
              value = FALSE, onLabel = "Oui", offLabel = "Non",
              onStatus = "danger", offStatus = "default", width = "100%")
          ),

          tags$div(class = "filter-section",
            tags$div(class = "filter-label", "% Action Direct"),
            sliderInput("filter_pct", NULL,
              min = 0, max = 100, value = c(0, 100), step = 5, width = "100%")
          ),

          actionButton("reset_filters",
            label = "Réinitialiser", icon = icon("rotate-left"),
            class = "filter-reset-btn", width = "100%"),

          tags$hr(style = "margin:14px 0;border-color:var(--itie-green-light);"),
          uiOutput("filter_count")
        )
      )
    ),

    # Contenu principal avec onglets Shiny natifs
    column(10,
      tags$div(class = "main-content",

        # ── tabsetPanel Shiny natif — fiable et réactif ──────────────────────
        tabsetPanel(
          id = "main_tabs",
          type = "tabs",

          tabPanel(
            title = tags$span(tags$i(class = "fas fa-gauge-high"), " Tableau de bord"),
            value = "dashboard",
            tags$div(style = "padding-top:20px;", dashboardUI("dashboard"))
          ),

          tabPanel(
            title = tags$span(tags$i(class = "fas fa-magnifying-glass"), " Recherche"),
            value = "search",
            tags$div(style = "padding-top:20px;", searchUI("search"))
          ),

          tabPanel(
            title = tags$span(tags$i(class = "fas fa-user-shield"), " Analyse PPE"),
            value = "ppe",
            tags$div(style = "padding-top:20px;", ppeUI("ppe"))
          ),

          tabPanel(
            title = tags$span(tags$i(class = "fas fa-diagram-project"), " Réseaux"),
            value = "network",
            tags$div(style = "padding-top:20px;", networkUI("network"))
          ),

          tabPanel(
            title = tags$span(tags$i(class = "fas fa-map-location-dot"), " Cartographie"),
            value = "map",
            tags$div(style = "padding-top:20px;", mapUI("map"))
          )
        )
      )
    )
  ),

  # ── FOOTER ─────────────────────────────────────────────────────────────────
  tags$footer(class = "app-footer",
    tags$div(
      tags$span(class = "footer-brand", "OpenRBE"),
      " — Open Registre des Bénéficiaires Effectifs | ",
      "© ITIE Sénégal 2025 | Initiative pour la Transparence dans les Industries Extractives"
    ),
    tags$div(class = "footer-version", "Version 1.2 | Données : Registre 2021–2025")
  )
)

# =============================================================================
# SERVER
# =============================================================================
server <- function(input, output, session) {

  # ── Données filtrées — sliderInput retourne des vrais numériques ──────────
  filtered_data <- reactive({
    pct_min <- input$filter_pct[1]  # numérique natif avec sliderInput
    pct_max <- input$filter_pct[2]

    apply_filters(
      dt           = RBE_DATA,
      regions      = if (length(input$filter_region) > 0) input$filter_region else NULL,
      nationalites = if (length(input$filter_nat)    > 0) input$filter_nat    else NULL,
      pays_res     = if (length(input$filter_pays)   > 0) input$filter_pays   else NULL,
      greffes      = if (length(input$filter_greffe) > 0) input$filter_greffe else NULL,
      ppe_only     = isTRUE(input$filter_ppe),
      pct_min      = pct_min,
      pct_max      = pct_max
    )
  })

  # ── Compteur résultats filtres ────────────────────────────────────────────
  output$filter_count <- renderUI({
    n     <- nrow(filtered_data())
    total <- nrow(RBE_DATA)
    pct   <- round(100 * n / total)
    color <- if (n == total) "#008C45" else if (pct > 50) "#F4C300" else "#D62D20"

    tags$div(style = "text-align:center;padding:8px 0;",
      tags$div(style = paste0("font-size:1.6rem;font-weight:800;color:", color), fmt_number(n)),
      tags$div(style = "font-size:0.72rem;color:#6C757D;text-transform:uppercase;letter-spacing:0.4px;",
               "bénéficiaires affichés"),
      tags$div(style = "font-size:0.72rem;color:#aaa;margin-top:2px;",
               paste0(pct, "% du total"))
    )
  })

  # ── Reset filtres ─────────────────────────────────────────────────────────
  observeEvent(input$reset_filters, {
    updatePickerInput(session, "filter_region",   selected = character(0))
    updatePickerInput(session, "filter_nat",      selected = character(0))
    updatePickerInput(session, "filter_pays",     selected = character(0))
    updatePickerInput(session, "filter_greffe",   selected = character(0))
    updateSwitchInput(session, "filter_ppe",      value    = FALSE)
    updateSliderInput(session, "filter_pct",      value    = c(0, 100))
  })

  # ── Modules ───────────────────────────────────────────────────────────────
  dashboardServer("dashboard", filtered_data)
  searchServer("search",       reactive(RBE_DATA))
  ppeServer("ppe",             filtered_data)
  networkServer("network",     filtered_data)
  mapServer("map",             filtered_data)
}

shinyApp(ui = ui, server = server)
