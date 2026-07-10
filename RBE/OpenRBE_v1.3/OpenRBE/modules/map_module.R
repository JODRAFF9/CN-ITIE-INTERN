# =============================================================================
# OpenRBE - Module Cartographie v1.3
# Carte verrouillée sur le Sénégal — impossible de sortir des frontières
# ITIE Sénégal - modules/map_module.R
# =============================================================================

mapUI <- function(id) {
  ns <- shiny::NS(id)

  shiny::tagList(
    shiny::fluidRow(
      shiny::column(12,
        shiny::div(class = "chart-card",
          shiny::div(class = "chart-title",
            shiny::icon("map"),
            " Cartographie des entreprises extractives au Sénégal"
          ),
          shiny::div(class = "map-controls",
            shiny::radioButtons(
              ns("map_metric"),
              "Indicateur affiché :",
              choices = c(
                "Nombre d'entreprises"    = "n_entreprises",
                "Nombre de bénéficiaires" = "n_beneficiaires",
                "Nombre de PPE"           = "n_ppe"
              ),
              selected = "n_beneficiaires",
              inline   = TRUE
            )
          ),
          leaflet::leafletOutput(ns("senegal_map"), height = "530px"),
          shiny::div(class = "map-note",
            shiny::icon("info-circle"),
            " Cliquez sur un cercle pour le détail de la région.",
            " Les cercles sont proportionnels à l'indicateur sélectionné."
          )
        )
      )
    ),

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

    # Bornes strictes du Sénégal
    SN_LAT_MIN <- 12.0
    SN_LAT_MAX <- 16.7
    SN_LNG_MIN <- -17.6
    SN_LNG_MAX <- -11.3
    SN_LNG_CTR <- -14.4
    SN_LAT_CTR <-  14.4

    map_data <- shiny::reactive({
      shiny::req(nrow(filtered_data()) > 0)
      dist <- filtered_data()[!is.na(region), .(
        n_beneficiaires = .N,
        n_entreprises   = data.table::uniqueN(denomination_sociale),
        n_ppe           = sum(est_ppe_bool, na.rm = TRUE)
      ), by = region]
      coords <- get_region_coords()
      merged <- merge(dist, coords, by = "region", all.x = TRUE)
      merged[!is.na(merged$lat)]
    })

    # Rendu initial — carte fixée, tuile OpenStreetMap filtrée sur le Sénégal
    output$senegal_map <- leaflet::renderLeaflet({
      leaflet::leaflet(
        options = leaflet::leafletOptions(
          minZoom            = 6,
          maxZoom            = 10,
          maxBoundsViscosity = 1.0,
          zoomControl        = TRUE
        )
      ) |>
        leaflet::addProviderTiles(
          "CartoDB.Positron",
          options = leaflet::providerTileOptions(noWrap = TRUE)
        ) |>
        # Vue initiale centrée sur le Sénégal
        leaflet::setView(lng = SN_LNG_CTR, lat = SN_LAT_CTR, zoom = 7) |>
        # Verrou dur sur les limites géographiques
        leaflet::setMaxBounds(
          lng1 = SN_LNG_MIN, lat1 = SN_LAT_MIN,
          lng2 = SN_LNG_MAX, lat2 = SN_LAT_MAX
        )
    })

    # Mise à jour des marqueurs
    shiny::observe({
      shiny::req(nrow(map_data()) > 0)
      dt      <- map_data()
      metric  <- input$map_metric
      values  <- dt[[metric]]
      max_val <- max(values, na.rm = TRUE)
      if (is.na(max_val) || max_val == 0) max_val <- 1

      # Rayon proportionnel entre 12 et 55 px
      radii <- 12 + (values / max_val) * 43

      # Palette verte ITIE
      pal <- leaflet::colorNumeric(
        palette = c("#c7e9c0", "#41ab5d", "#005A2E"),
        domain  = c(0, max_val)
      )

      label_metric <- switch(metric,
        "n_entreprises"   = "Entreprises",
        "n_beneficiaires" = "Bénéficiaires",
        "n_ppe"           = "PPE"
      )

      popups <- paste0(
        "<div style='font-family:Inter,Arial,sans-serif;",
        "min-width:200px;padding:8px 10px;'>",
        "<div style='font-size:15px;font-weight:700;color:#008C45;",
        "margin-bottom:8px;border-bottom:2px solid #008C45;padding-bottom:4px;'>",
        dt$region, "</div>",
        "<table style='width:100%;font-size:13px;border-collapse:collapse;'>",
        "<tr><td style='padding:3px 0;'>Entreprises</td>",
        "<td style='text-align:right;font-weight:600;'>",
        dt$n_entreprises, "</td></tr>",
        "<tr><td style='padding:3px 0;'>Bénéficiaires</td>",
        "<td style='text-align:right;font-weight:600;'>",
        dt$n_beneficiaires, "</td></tr>",
        "<tr><td style='padding:3px 0;color:#D62D20;font-weight:600;'>PPE</td>",
        "<td style='text-align:right;color:#D62D20;font-weight:700;'>",
        dt$n_ppe, "</td></tr>",
        "</table></div>"
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
          fillOpacity  = 0.85,
          color        = "#005A2E",
          weight       = 1.5,
          popup        = popups,
          label        = paste0(dt$region, " — ", label_metric, " : ", values),
          labelOptions = leaflet::labelOptions(
            style = list(
              "font-weight"  = "bold",
              "font-size"    = "13px",
              "border-color" = "#008C45",
              "color"        = "#005A2E"
            )
          )
        ) |>
        leaflet::addLegend(
          position  = "bottomright",
          pal       = pal,
          values    = values,
          title     = label_metric,
          opacity   = 0.85,
          labFormat = leaflet::labelFormat(digits = 0)
        )
    })

    # Tableau récapitulatif régional
    output$region_table <- DT::renderDataTable({
      shiny::req(nrow(map_data()) > 0)
      display <- map_data()[, .(
        "Région"          = region,
        "Entreprises"     = n_entreprises,
        "Bénéficiaires"   = n_beneficiaires,
        "dont PPE"        = n_ppe
      )]
      data.table::setorder(display, -Bénéficiaires)

      DT::datatable(
        display,
        options  = list(
          pageLength = 15, dom = "t",
          language = list(
            url = "//cdn.datatables.net/plug-ins/1.10.25/i18n/French.json"
          )
        ),
        class    = "table table-striped table-hover",
        rownames = FALSE
      ) |>
        DT::formatStyle(
          "dont PPE",
          color      = DT::styleInterval(0, c("inherit", "#D62D20")),
          fontWeight = DT::styleInterval(0, c("normal", "bold"))
        )
    })
  })
}
