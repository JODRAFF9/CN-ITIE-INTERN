# =============================================================================
# OpenRBE — Open Registre des Bénéficiaires Effectifs
# ITIE Sénégal | Plateforme nationale de transparence extractive
# Version 1.0 | app.R principal
# =============================================================================

# ── Packages requis ──────────────────────────────────────────────────────────
suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(shinyWidgets)
  library(DT)
  library(plotly)
  library(highcharter)
  library(leaflet)
  library(visNetwork)
  library(data.table)
  library(readxl)
  library(openxlsx)
  library(dplyr)
  library(stringr)
  library(htmltools)
})

# ── Chargement des modules et fonctions ──────────────────────────────────────
source("R/load_data.R")
source("R/indicators.R")
source("R/charts.R")
source("R/helpers.R")
source("modules/dashboard_module.R")
source("modules/search_module.R")
source("modules/ppe_module.R")
source("modules/network_module.R")
source("modules/map_module.R")

# ── Chargement initial des données ───────────────────────────────────────────
RBE_DATA <- load_rbe_data("data/rbe_data.xlsx")

# ── Listes pour les filtres ───────────────────────────────────────────────────
ALL_REGIONS      <- sort(unique(RBE_DATA$region[!is.na(RBE_DATA$region)]))
ALL_NATIONALITIES<- sort(unique(RBE_DATA$nationalite[!is.na(RBE_DATA$nationalite)]))
ALL_PAYS         <- sort(unique(RBE_DATA$pays_residence[!is.na(RBE_DATA$pays_residence)]))
ALL_GREFFES      <- sort(unique(RBE_DATA$greffe[!is.na(RBE_DATA$greffe)]))

# =============================================================================
# UI
# =============================================================================
ui <- fluidPage(
  
  # ── Head : meta, fonts, CSS, JS ──────────────────────────────────────────────
  tags$head(
    tags$meta(charset = "utf-8"),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    tags$meta(name = "description",
              content = "OpenRBE — Registre des Bénéficiaires Effectifs du secteur extractif sénégalais"),
    tags$title("OpenRBE | ITIE Sénégal"),
    
    # Google Fonts
    tags$link(
      rel  = "preconnect",
      href = "https://fonts.googleapis.com"
    ),
    tags$link(
      rel  = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap"
    ),
    
    # Font Awesome
    tags$link(
      rel  = "stylesheet",
      href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"
    ),
    
    # CSS personnalisé ITIE
    tags$link(rel = "stylesheet", href = "css/styles.css"),
    
    # JS personnalisé
    tags$script(src = "js/custom.js")
  ),
  
  # ── HEADER ───────────────────────────────────────────────────────────────────
  tags$header(class = "main-header",
    tags$div(class = "header-inner",
      tags$div(class = "header-logo",
        tags$img(
          src   = "img/logo_itie.png",
          alt   = "Logo ITIE Sénégal",
          title = "Initiative pour la Transparence dans les Industries Extractives du Sénégal"
        )
      ),
      tags$div(class = "header-divider"),
      tags$div(class = "header-text",
        tags$h1(class = "header-title",
          tags$span(class = "title-open", "Open"),
          tags$span(class = "title-rbe", "RBE")
        ),
        tags$p(class = "header-subtitle",
               "Open Registre des Bénéficiaires Effectifs"),
        tags$p(class = "header-tagline",
               "Plateforme nationale de consultation des bénéficiaires effectifs",
               "des entreprises du secteur extractif au Sénégal")
      ),
      tags$div(class = "ms-auto",
        tags$div(class = "header-badge",
          icon("shield-halved"), " Données officielles ITIE"
        )
      )
    ),
    
    # Barre de navigation
    tags$nav(class = "nav-bar",
      tags$ul(class = "nav",
        tags$li(class = "nav-item",
          tags$a(class = "nav-link active", href = "#tab-dashboard",
                 `data-bs-toggle` = "tab",
                 icon("gauge-high"), " Tableau de bord")
        ),
        tags$li(class = "nav-item",
          tags$a(class = "nav-link", href = "#tab-search",
                 `data-bs-toggle` = "tab",
                 icon("magnifying-glass"), " Recherche")
        ),
        tags$li(class = "nav-item",
          tags$a(class = "nav-link", href = "#tab-ppe",
                 `data-bs-toggle` = "tab",
                 icon("user-shield"), " Analyse PPE")
        ),
        tags$li(class = "nav-item",
          tags$a(class = "nav-link", href = "#tab-network",
                 `data-bs-toggle` = "tab",
                 icon("diagram-project"), " Réseaux")
        ),
        tags$li(class = "nav-item",
          tags$a(class = "nav-link", href = "#tab-map",
                 `data-bs-toggle` = "tab",
                 icon("map-location-dot"), " Cartographie")
        )
      )
    )
  ),
  
  # ── CORPS PRINCIPAL ───────────────────────────────────────────────────────────
  fluidRow(
    
    # ── SIDEBAR FILTRES ─────────────────────────────────────────────────────────
    column(2,
      tags$div(class = "main-content", style = "padding-right: 8px;",
        tags$div(class = "sidebar-panel",
          
          tags$div(class = "sidebar-title",
            icon("filter"), " Filtres"
          ),
          
          # Région
          tags$div(class = "filter-section",
            tags$div(class = "filter-label", "Région"),
            shinyWidgets::pickerInput(
              "filter_region",
              label    = NULL,
              choices  = ALL_REGIONS,
              selected = NULL,
              multiple = TRUE,
              options  = shinyWidgets::pickerOptions(
                actionsBox        = TRUE,
                selectedTextFormat= "count > 1",
                countSelectedText = "{0} régions",
                noneSelectedText  = "Toutes",
                liveSearch        = FALSE
              ),
              width = "100%"
            )
          ),
          
          # Nationalité
          tags$div(class = "filter-section",
            tags$div(class = "filter-label", "Nationalité"),
            shinyWidgets::pickerInput(
              "filter_nat",
              label    = NULL,
              choices  = ALL_NATIONALITIES,
              selected = NULL,
              multiple = TRUE,
              options  = shinyWidgets::pickerOptions(
                actionsBox        = TRUE,
                selectedTextFormat= "count > 1",
                countSelectedText = "{0} nationalités",
                noneSelectedText  = "Toutes",
                liveSearch        = TRUE,
                liveSearchPlaceholder = "Chercher..."
              ),
              width = "100%"
            )
          ),
          
          # Pays résidence
          tags$div(class = "filter-section",
            tags$div(class = "filter-label", "Pays de résidence"),
            shinyWidgets::pickerInput(
              "filter_pays",
              label    = NULL,
              choices  = ALL_PAYS,
              selected = NULL,
              multiple = TRUE,
              options  = shinyWidgets::pickerOptions(
                actionsBox        = TRUE,
                selectedTextFormat= "count > 1",
                countSelectedText = "{0} pays",
                noneSelectedText  = "Tous",
                liveSearch        = TRUE,
                liveSearchPlaceholder = "Chercher..."
              ),
              width = "100%"
            )
          ),
          
          # Greffe
          tags$div(class = "filter-section",
            tags$div(class = "filter-label", "Greffe"),
            shinyWidgets::pickerInput(
              "filter_greffe",
              label    = NULL,
              choices  = ALL_GREFFES,
              selected = NULL,
              multiple = TRUE,
              options  = shinyWidgets::pickerOptions(
                noneSelectedText = "Tous"
              ),
              width = "100%"
            )
          ),
          
          # PPE
          tags$div(class = "filter-section",
            tags$div(class = "filter-label", "Statut PPE"),
            shinyWidgets::switchInput(
              "filter_ppe",
              label       = "PPE uniquement",
              value       = FALSE,
              onLabel     = "Oui",
              offLabel    = "Non",
              onStatus    = "danger",
              offStatus   = "default",
              width       = "100%",
              labelWidth  = "140px"
            )
          ),
          
          # Participation
          tags$div(class = "filter-section",
            tags$div(class = "filter-label", "% Action Direct"),
            shinyWidgets::sliderTextInput(
              "filter_pct",
              label    = NULL,
              choices  = seq(0, 100, by = 5),
              selected = c(0, 100),
              width    = "100%"
            )
          ),
          
          # Bouton reset
          actionButton(
            "reset_filters",
            label = "Réinitialiser les filtres",
            icon  = icon("rotate-left"),
            class = "filter-reset-btn",
            width = "100%"
          ),
          
          # Compteur résultats
          tags$hr(style = "margin: 14px 0; border-color: var(--itie-green-light);"),
          uiOutput("filter_count")
        )
      )
    ),
    
    # ── CONTENU PRINCIPAL ────────────────────────────────────────────────────────
    column(10,
      tags$div(class = "main-content",
        tags$div(class = "tab-content",
          
          # Page 1 : Tableau de bord
          tags$div(id = "tab-dashboard", class = "tab-pane fade show active",
            dashboardUI("dashboard")
          ),
          
          # Page 2 : Recherche
          tags$div(id = "tab-search", class = "tab-pane fade",
            searchUI("search")
          ),
          
          # Page 3 : PPE
          tags$div(id = "tab-ppe", class = "tab-pane fade",
            ppeUI("ppe")
          ),
          
          # Page 4 : Réseau
          tags$div(id = "tab-network", class = "tab-pane fade",
            networkUI("network")
          ),
          
          # Page 5 : Carte
          tags$div(id = "tab-map", class = "tab-pane fade",
            mapUI("map")
          )
        )
      )
    )
  ),
  
  # ── FOOTER ───────────────────────────────────────────────────────────────────
  tags$footer(class = "app-footer",
    tags$div(
      tags$span(class = "footer-brand", "OpenRBE"),
      " — Open Registre des Bénéficiaires Effectifs | ",
      "© ITIE Sénégal 2025 | Initiative pour la Transparence dans les Industries Extractives"
    ),
    tags$div(class = "footer-version",
             "Version 1.0 | Données : Registre 2021–2025")
  ),
  
  # ── Bootstrap JS pour onglets ─────────────────────────────────────────────
  tags$script(HTML("
    document.addEventListener('DOMContentLoaded', function() {
      // Activer les onglets Bootstrap manuellement
      var tabLinks = document.querySelectorAll('.nav-link[data-bs-toggle=\"tab\"]');
      tabLinks.forEach(function(link) {
        link.addEventListener('click', function(e) {
          e.preventDefault();
          // Désactiver tous
          tabLinks.forEach(function(l) { l.classList.remove('active'); });
          document.querySelectorAll('.tab-pane').forEach(function(p) {
            p.classList.remove('show', 'active');
          });
          // Activer courant
          this.classList.add('active');
          var target = document.querySelector(this.getAttribute('href'));
          if (target) {
            target.classList.add('show', 'active');
            // Notifier Shiny du changement d'onglet
            Shiny.setInputValue('current_tab',
              this.getAttribute('href').replace('#tab-', ''));
          }
        });
      });
    });
  "))
)

# =============================================================================
# SERVER
# =============================================================================
server <- function(input, output, session) {
  
  # ── Données filtrées réactives ─────────────────────────────────────────────
  filtered_data <- reactive({
    apply_filters(
      dt           = RBE_DATA,
      regions      = if (length(input$filter_region) > 0) input$filter_region else NULL,
      nationalites = if (length(input$filter_nat)    > 0) input$filter_nat    else NULL,
      pays_res     = if (length(input$filter_pays)   > 0) input$filter_pays   else NULL,
      greffes      = if (length(input$filter_greffe) > 0) input$filter_greffe else NULL,
      ppe_only     = isTRUE(input$filter_ppe),
      pct_min      = as.numeric(input$filter_pct[1]),
      pct_max      = as.numeric(input$filter_pct[2])
    )
  })
  
  # ── Compteur filtres ───────────────────────────────────────────────────────
  output$filter_count <- renderUI({
    n      <- nrow(filtered_data())
    total  <- nrow(RBE_DATA)
    pct    <- round(100 * n / total)
    color  <- if (n == total) "#008C45" else if (pct > 50) "#F4C300" else "#D62D20"
    
    tagList(
      tags$div(style = paste0("text-align:center;padding:8px 0;"),
        tags$div(
          style = paste0("font-size:1.6rem;font-weight:800;color:", color),
          fmt_number(n)
        ),
        tags$div(
          style = "font-size:0.72rem;color:#6C757D;text-transform:uppercase;letter-spacing:0.4px;",
          "bénéficiaires affichés"
        ),
        tags$div(
          style = "font-size:0.72rem;color:#aaa;margin-top:2px;",
          paste0(pct, "% du total")
        )
      )
    )
  })
  
  # ── Reset filtres ──────────────────────────────────────────────────────────
  observeEvent(input$reset_filters, {
    shinyWidgets::updatePickerInput(session, "filter_region",   selected = character(0))
    shinyWidgets::updatePickerInput(session, "filter_nat",      selected = character(0))
    shinyWidgets::updatePickerInput(session, "filter_pays",     selected = character(0))
    shinyWidgets::updatePickerInput(session, "filter_greffe",   selected = character(0))
    shinyWidgets::updateSwitchInput(session, "filter_ppe", value = FALSE)
    shinyWidgets::updateSliderTextInput(session, "filter_pct",
                                        selected = c("0", "100"))
  })
  
  # ── Modules ───────────────────────────────────────────────────────────────
  dashboardServer("dashboard", filtered_data)
  searchServer("search",       reactive(RBE_DATA))
  ppeServer("ppe",             filtered_data)
  networkServer("network",     filtered_data)
  mapServer("map",             filtered_data)
  
}

# =============================================================================
# Lancement de l'application
# =============================================================================
shinyApp(ui = ui, server = server)
