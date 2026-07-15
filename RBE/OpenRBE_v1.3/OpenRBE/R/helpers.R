# =============================================================================
# OpenRBE - Utilitaires généraux
# ITIE Sénégal - R/helpers.R
# =============================================================================

#' Formater un nombre avec séparateur de milliers
fmt_number <- function(x) {
  if (is.na(x) || !is.numeric(x)) return("—")
  format(round(x, 2), big.mark = " ", nsmall = 0, scientific = FALSE)
}

#' Formater un pourcentage
fmt_pct <- function(x) {
  if (is.na(x) || !is.numeric(x)) return("—")
  paste0(round(x, 1), "%")
}

#' Créer une carte KPI HTML
kpi_card <- function(icon, label, value, color = "#008C45", sub_label = NULL) {
  sub_html <- if (!is.null(sub_label)) {
    paste0('<div class="kpi-sublabel">', sub_label, '</div>')
  } else ""
  
  htmltools::HTML(paste0(
    '<div class="kpi-card" style="border-top: 4px solid ', color, '">',
    '  <div class="kpi-icon" style="color:', color, '">',
    '    <i class="fas ', icon, '"></i>',
    '  </div>',
    '  <div class="kpi-content">',
    '    <div class="kpi-value">', value, '</div>',
    '    <div class="kpi-label">', label, '</div>',
    sub_html,
    '  </div>',
    '</div>'
  ))
}

#' Appliquer les filtres globaux sur le data.table
apply_filters <- function(dt,
                          regions       = NULL,
                          nationalites  = NULL,
                          pays_res      = NULL,
                          greffes       = NULL,
                          ppe_only      = FALSE,
                          pct_min       = 0,
                          pct_max       = 100) {
  res <- data.table::copy(dt)

  # Filtre région
  if (!is.null(regions) && length(regions) > 0 && !all(regions == ""))
    res <- res[region %in% regions]

  # Filtre nationalité
  if (!is.null(nationalites) && length(nationalites) > 0 && !all(nationalites == ""))
    res <- res[nationalite %in% nationalites]

  # Filtre pays résidence
  if (!is.null(pays_res) && length(pays_res) > 0 && !all(pays_res == ""))
    res <- res[pays_residence %in% pays_res]

  # Filtre greffe
  if (!is.null(greffes) && length(greffes) > 0 && !all(greffes == ""))
    res <- res[greffe %in% greffes]

  # Filtre PPE
  if (isTRUE(ppe_only))
    res <- res[est_ppe_bool == TRUE]

  # Filtre % participation — conversion numérique robuste
  pct_min_n <- suppressWarnings(as.numeric(pct_min))
  pct_max_n <- suppressWarnings(as.numeric(pct_max))

  if (!is.null(pct_min_n) && !is.null(pct_max_n) &&
      !is.na(pct_min_n)   && !is.na(pct_max_n)   &&
      !(pct_min_n == 0 && pct_max_n == 100)) {
    res <- res[is.na(pct_action_direct) |
               (pct_action_direct >= pct_min_n & pct_action_direct <= pct_max_n)]
  }

  res
}

#' Coordonnées géographiques des régions sénégalaises
get_region_coords <- function() {
  data.frame(
    region    = c("Dakar", "Thiès", "Diourbel", "Fatick", "Kaolack",
                  "Kédougou", "Mbour", "Tambacounda", "Ziguinchor",
                  "Louga", "Saint-Louis", "Matam", "Kolda", "Sédhiou",
                  "Kaffrine"),
    lat       = c(14.693, 14.788, 14.655, 14.339, 14.152,
                  12.560, 14.408, 13.771, 12.565,
                  15.617, 16.028, 15.658, 12.886, 12.708,
                  14.106),
    lng       = c(-17.447, -16.924, -16.232, -16.411, -16.073,
                  -12.186, -16.965, -13.667, -16.272,
                  -16.224, -16.499, -13.263, -14.944, -15.557,
                  -15.551),
    stringsAsFactors = FALSE
  )
}

#' Badge HTML pour statut PPE
ppe_badge <- function(is_ppe) {
  if (isTRUE(is_ppe)) {
    '<span class="badge badge-ppe">PPE</span>'
  } else {
    '<span class="badge badge-nonppe">Non PPE</span>'
  }
}

#' Truncature sécurisée
safe_trunc <- function(x, width = 40) {
  ifelse(nchar(x) > width, paste0(substr(x, 1, width - 3), "..."), x)
}
