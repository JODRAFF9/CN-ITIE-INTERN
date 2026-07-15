# =============================================================================
# OpenRBE - Module Cartographie
# ITIE Sénégal - modules/map_module.R
# =============================================================================

mapUI <- function(id) {
  ns <- shiny::NS(id)
  
  shiny::tagList(
    shiny::fluidRow(
      shiny::column(12,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("map"), " Cartographie des entreprises extractives au Sénégal"
          ),
          shiny::div(class = "map-controls",
            shiny::radioButtons(
              ns("map_metric"),
              "Indicateur affiché:",
              choices  = c(
                "Nombre d'entreprises"     = "n_entreprises",
                "Nombre de bénéficiaires"  = "n_beneficiaires",
                "Nombre de PPE"            = "n_ppe"
              ),
              selected = "n_beneficiaires",
              inline   = TRUE
            )
          ),
          leaflet::leafletOutput(ns("senegal_map"), height = "520px"),
          shiny::div(class = "map-note",
            shiny::icon("info-circle"),
            " Les cercles sont proportionnels à l'indicateur sélectionné. ",
            "Cliquez sur un cercle pour les détails."
          )
        )
      )
    ),
    
    # Tableau récapitulatif régional
    shiny::fluidRow(
      shiny::column(12,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("table"), " Récapitulatif par région"
          ),
          DT::dataTableOutput(ns("region_table"))
        )
      )
    )
  )
}

mapServer <- function(id, filtered_data) {
  shiny::moduleServer(id, function(input, output, session) {
    
    # Données géographiques agrégées
    map_data <- shiny::reactive({
      shiny::req(nrow(filtered_data()) > 0)
      
      dist <- filtered_data()[!is.na(region), .(
        n_beneficiaires = .N,
        n_entreprises   = data.table::uniqueN(denomination_sociale),
        n_ppe           = sum(est_ppe_bool, na.rm = TRUE)
      ), by = region]
      
      coords <- get_region_coords()
      merged <- merge(dist, coords, by = "region", all.x = TRUE)
      merged <- merged[!is.na(merged$lat), ]
      merged
    })
    
    # Carte Leaflet
    output$senegal_map <- leaflet::renderLeaflet({
      leaflet::leaflet() |>
        leaflet::addTiles(
          urlTemplate = "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
          attribution  = "© OpenStreetMap | © CartoDB | ITIE Sénégal OpenRBE"
        ) |>
        leaflet::setView(lng = -14.5, lat = 14.5, zoom = 6)
    })
    
    # Mise à jour des marqueurs réactifs
    shiny::observe({
      shiny::req(nrow(map_data()) > 0)
      dt       <- map_data()
      metric   <- input$map_metric
      
      # Valeurs selon métrique
      values   <- dt[[metric]]
      max_val  <- max(values, na.rm = TRUE)
      if (max_val == 0) max_val <- 1
      
      # Rayon proportionnel
      radii <- 10 + (values / max_val) * 50
      
      # Couleurs ITIE selon intensité
      pal <- leaflet::colorNumeric(
        palette = c("#90EE90", "#008C45", "#005A2E"),
        domain  = c(0, max_val)
      )
      
      label_metric <- switch(metric,
        "n_entreprises"  = "Entreprises",
        "n_beneficiaires"= "Bénéficiaires",
        "n_ppe"          = "PPE"
      )
      
      popups <- paste0(
        "<div style='font-family:Inter,Arial;min-width:160px'>",
        "<h4 style='color:#008C45;margin:0 0 6px'>", dt$region, "</h4>",
        "<b>Entreprises:</b> ", dt$n_entreprises, "<br>",
        "<b>Bénéficiaires:</b> ", dt$n_beneficiaires, "<br>",
        "<b>PPE:</b> <span style='color:#D62D20;font-weight:bold'>", dt$n_ppe, "</span>",
        "</div>"
      )
      
      leaflet::leafletProxy("senegal_map", session) |>
        leaflet::clearShapes() |>
        leaflet::clearControls() |>
        leaflet::addCircleMarkers(
          data         = dt,
          lat          = ~lat,
          lng          = ~lng,
          radius       = radii,
          fillColor    = pal(values),
          fillOpacity  = 0.8,
          color        = "#1A1A1A",
          weight       = 1.5,
          popup        = popups,
          label        = paste0(dt$region, " — ", label_metric, ": ", values),
          labelOptions = leaflet::labelOptions(
            style = list("font-weight" = "bold", "font-size" = "13px")
          )
        ) |>
        leaflet::addLegend(
          position  = "bottomright",
          pal       = pal,
          values    = values,
          title     = label_metric,
          opacity   = 0.8
        )
    })
    
    # Tableau régional
    output$region_table <- DT::renderDataTable({
      shiny::req(nrow(map_data()) > 0)
      
      display <- map_data()[, .(
        "Région"         = region,
        "Entreprises"    = n_entreprises,
        "Bénéficiaires"  = n_beneficiaires,
        "PPE"            = n_ppe
      )]
      data.table::setorder(display, -Bénéficiaires)
      
      DT::datatable(
        display,
        options  = list(
          pageLength = 15,
          dom        = "t",
          language   = list(
            url = "//cdn.datatables.net/plug-ins/1.10.25/i18n/French.json"
          )
        ),
        class    = "table table-striped table-hover",
        rownames = FALSE
      ) |>
        DT::formatStyle("PPE",
                        color      = DT::styleInterval(0, c("inherit", "#D62D20")),
                        fontWeight = DT::styleInterval(0, c("normal", "bold")))
    })
  })
}
