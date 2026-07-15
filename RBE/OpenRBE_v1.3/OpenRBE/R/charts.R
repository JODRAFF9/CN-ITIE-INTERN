# =============================================================================
# OpenRBE - Fonctions graphiques
# ITIE Sénégal - R/charts.R
# =============================================================================

ITIE_GREEN  <- "#008C45"
ITIE_YELLOW <- "#F4C300"
ITIE_RED    <- "#D62D20"
ITIE_BLACK  <- "#1A1A1A"
ITIE_LIGHT  <- "#F8F9FA"

#' Bar chart Plotly - Distribution par nationalité
make_nationality_chart <- function(dt) {
  dist <- get_nationality_distribution(dt, top_n = 15)
  
  plotly::plot_ly(
    data   = dist,
    x      = ~reorder(nationalite, N),
    y      = ~N,
    type   = "bar",
    marker = list(
      color       = ITIE_GREEN,
      line        = list(color = ITIE_BLACK, width = 0.5)
    ),
    hovertemplate = "<b>%{x}</b><br>Bénéficiaires: %{y}<extra></extra>"
  ) |>
    plotly::layout(
      title      = list(text = "", font = list(size = 14)),
      xaxis      = list(
        title          = "",
        tickfont       = list(size = 11),
        categoryorder  = "total descending"
      ),
      yaxis      = list(title = "Nombre de bénéficiaires", gridcolor = "#e9ecef"),
      plot_bgcolor  = "white",
      paper_bgcolor = "white",
      margin        = list(l = 60, r = 20, t = 10, b = 120),
      font          = list(family = "Inter, Arial, sans-serif")
    )
}

#' Pie chart Plotly - Distribution PPE
make_ppe_pie_chart <- function(dt) {
  dist <- get_ppe_distribution(dt)
  
  plotly::plot_ly(
    data   = dist,
    labels = ~statut,
    values = ~n,
    type   = "pie",
    marker = list(colors = c(ITIE_RED, ITIE_GREEN)),
    textinfo      = "label+percent",
    hovertemplate = "<b>%{label}</b><br>Nombre: %{value}<br>%{percent}<extra></extra>"
  ) |>
    plotly::layout(
      showlegend    = TRUE,
      legend        = list(orientation = "h", x = 0.2, y = -0.1),
      plot_bgcolor  = "white",
      paper_bgcolor = "white",
      margin        = list(l = 20, r = 20, t = 20, b = 60),
      font          = list(family = "Inter, Arial, sans-serif")
    )
}

#' Bar chart Highcharter - Distribution régionale
make_regional_chart <- function(dt) {
  dist <- get_regional_distribution(dt)
  
  highcharter::highchart() |>
    highcharter::hc_chart(type = "bar", style = list(fontFamily = "Inter, Arial, sans-serif")) |>
    highcharter::hc_title(text = NULL) |>
    highcharter::hc_xAxis(
      categories = dist$region,
      title      = list(text = "")
    ) |>
    highcharter::hc_yAxis(title = list(text = "Nombre")) |>
    highcharter::hc_add_series(
      name  = "Bénéficiaires",
      data  = dist$n_beneficiaires,
      color = ITIE_GREEN
    ) |>
    highcharter::hc_add_series(
      name  = "Entreprises",
      data  = dist$n_entreprises,
      color = ITIE_YELLOW
    ) |>
    highcharter::hc_tooltip(shared = TRUE) |>
    highcharter::hc_plotOptions(bar = list(
      dataLabels = list(enabled = TRUE, style = list(fontSize = "10px"))
    )) |>
    highcharter::hc_legend(enabled = TRUE) |>
    highcharter::hc_credits(enabled = FALSE)
}

#' Histogramme Plotly - Distribution des participations
make_ownership_histogram <- function(dt) {
  vals <- get_ownership_distribution(dt)
  
  plotly::plot_ly(
    x    = vals,
    type = "histogram",
    nbinsx = 20,
    marker = list(
      color = ITIE_YELLOW,
      line  = list(color = ITIE_BLACK, width = 0.5)
    ),
    hovertemplate = "Participation: %{x}%<br>Bénéficiaires: %{y}<extra></extra>"
  ) |>
    plotly::layout(
      xaxis         = list(title = "% Action Direct", gridcolor = "#e9ecef"),
      yaxis         = list(title = "Nombre de bénéficiaires", gridcolor = "#e9ecef"),
      plot_bgcolor  = "white",
      paper_bgcolor = "white",
      margin        = list(l = 60, r = 20, t = 10, b = 60),
      font          = list(family = "Inter, Arial, sans-serif")
    )
}

#' Bar chart Plotly - PPE par nationalité
make_ppe_nationality_chart <- function(dt) {
  ppe_dt <- dt[est_ppe_bool == TRUE & !is.na(nationalite)]
  if (nrow(ppe_dt) == 0) {
    return(plotly::plot_ly() |>
             plotly::layout(title = "Aucun PPE dans la sélection"))
  }
  dist <- ppe_dt[, .N, by = nationalite]
  data.table::setorder(dist, -N)
  
  plotly::plot_ly(
    data   = dist,
    x      = ~nationalite,
    y      = ~N,
    type   = "bar",
    marker = list(color = ITIE_RED),
    hovertemplate = "<b>%{x}</b><br>PPE: %{y}<extra></extra>"
  ) |>
    plotly::layout(
      xaxis         = list(title = "", tickfont = list(size = 11)),
      yaxis         = list(title = "Nombre de PPE", gridcolor = "#e9ecef"),
      plot_bgcolor  = "white",
      paper_bgcolor = "white",
      margin        = list(l = 60, r = 20, t = 10, b = 100),
      font          = list(family = "Inter, Arial, sans-serif")
    )
}

#' Graphe réseau visNetwork - Entreprise -> Bénéficiaire
make_network_graph <- function(dt, max_companies = 30) {
  
  # Limiter pour performance
  top_companies <- dt[, .N, by = denomination_sociale]
  data.table::setorder(top_companies, -N)
  selected <- head(top_companies$denomination_sociale, max_companies)
  sub_dt   <- dt[denomination_sociale %in% selected]
  
  # Noeuds entreprises
  companies <- unique(sub_dt$denomination_sociale)
  bens      <- unique(sub_dt$prenom_nom)
  
  node_companies <- data.frame(
    id    = paste0("C_", seq_along(companies)),
    label = stringr::str_trunc(companies, 30),
    group = "Entreprise",
    title = companies,
    shape = "dot",
    size  = 20,
    color = list(background = ITIE_GREEN, border = ITIE_BLACK,
                 highlight = list(background = ITIE_YELLOW, border = ITIE_BLACK)),
    font  = list(size = 12),
    stringsAsFactors = FALSE
  )
  
  # Mapping bénéficiaires
  ben_ids <- data.frame(
    prenom_nom = bens,
    id         = paste0("B_", seq_along(bens)),
    stringsAsFactors = FALSE
  )
  
  node_bens <- data.frame(
    id    = ben_ids$id,
    label = stringr::str_trunc(bens, 25),
    group = "Bénéficiaire",
    title = bens,
    shape = "dot",
    size  = 12,
    color = list(background = ITIE_YELLOW, border = ITIE_BLACK,
                 highlight = list(background = ITIE_RED, border = ITIE_BLACK)),
    font  = list(size = 10),
    stringsAsFactors = FALSE
  )
  
  nodes <- rbind(node_companies, node_bens)
  
  # Mapping entreprises
  comp_ids <- data.frame(
    denomination_sociale = companies,
    id                   = paste0("C_", seq_along(companies)),
    stringsAsFactors     = FALSE
  )
  
  # Arêtes
  edges_raw <- merge(
    sub_dt[, .(denomination_sociale, prenom_nom, pct_action_direct)],
    comp_ids,
    by = "denomination_sociale"
  )
  edges_raw <- merge(edges_raw, ben_ids, by = "prenom_nom")
  edges_raw <- edges_raw[!duplicated(edges_raw[, c("id.x", "id.y")]), ]
  
  edges <- data.frame(
    from   = edges_raw$id.x,
    to     = edges_raw$id.y,
    title  = ifelse(
      is.na(edges_raw$pct_action_direct), "",
      paste0(edges_raw$pct_action_direct, "%")
    ),
    width  = 1,
    color  = list(color = "#cccccc", highlight = ITIE_RED),
    stringsAsFactors = FALSE
  )
  
  list(nodes = nodes, edges = edges)
}
