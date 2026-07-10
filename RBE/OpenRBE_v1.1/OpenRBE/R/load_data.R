# =============================================================================
# OpenRBE - Chargement et nettoyage des données RBE
# ITIE Sénégal - R/load_data.R
# =============================================================================

#' Charger et nettoyer les données du RBE
#'
#' @param path Chemin vers le fichier Excel
#' @return data.table nettoyé contenant les données RBE
load_rbe_data <- function(path = "data/rbe_data.xlsx") {
  
  # Vérification existence fichier
  if (!file.exists(path)) {
    stop(paste("Fichier introuvable:", path))
  }
  
  # Lecture Excel - feuille principale avec bon header
  raw <- readxl::read_excel(
    path,
    sheet    = "Feuil1",
    skip     = 1,
    col_names = TRUE
  )
  
  # Conversion en data.table pour performance
  dt <- data.table::as.data.table(raw)
  
  # Renommage harmonisé des colonnes
  data.table::setnames(dt, old = names(dt), new = c(
    "region",
    "denomination_sociale",
    "prenom_nom",
    "date_acquisition",
    "pct_action_direct",
    "pct_voix_direct",
    "nationalite",
    "pays_residence",
    "est_ppe",
    "fonction_ppe",
    "nom_ppe",
    "greffe",
    "regions"
  ))
  
  # Suppression lignes vides ou lignes-étiquettes (années)
  dt <- dt[!is.na(denomination_sociale)]
  dt <- dt[!grepl("^\\d{4}$", as.character(denomination_sociale))]
  
  # Nettoyage textes : suppression espaces inutiles
  cols_char <- c("region", "denomination_sociale", "prenom_nom",
                 "nationalite", "pays_residence", "greffe", "regions",
                 "fonction_ppe", "nom_ppe")
  dt[, (cols_char) := lapply(.SD, function(x) stringr::str_trim(as.character(x))),
     .SDcols = cols_char]
  
  # Remplacer "NA" texte par vrai NA
  dt[, (cols_char) := lapply(.SD, function(x) ifelse(x == "NA", NA_character_, x)),
     .SDcols = cols_char]
  
  # Harmonisation colonne PPE
  # est_ppe : NaN -> FALSE, 0 -> FALSE, 1 ou pays -> TRUE
  dt[, est_ppe_bool := FALSE]
  dt[!is.na(est_ppe) & !(as.character(est_ppe) %in% c("0", "NA")), est_ppe_bool := TRUE]
  
  # Conversion pourcentages en numérique
  dt[, pct_action_direct := suppressWarnings(as.numeric(pct_action_direct))]
  dt[, pct_voix_direct   := suppressWarnings(as.numeric(pct_voix_direct))]
  
  # Limiter les valeurs aberrantes (>100% possible en multi-classes)
  dt[!is.na(pct_action_direct) & pct_action_direct > 100, pct_action_direct := 100]
  
  # Conversion date
  dt[, date_acquisition := suppressWarnings(
    as.POSIXct(as.character(date_acquisition), format = "%Y-%m-%d %H:%M:%OS")
  )]
  dt[, annee_acquisition := data.table::year(date_acquisition)]
  
  # Harmonisation casse nationalité
  dt[, nationalite := stringr::str_to_upper(stringr::str_trim(nationalite))]
  dt[, pays_residence := stringr::str_to_upper(stringr::str_trim(pays_residence))]
  
  # Harmonisation région
  dt[, region := stringr::str_to_title(stringr::str_trim(region))]
  
  # Déduplication légère (même bénéficiaire + entreprise)
  dt <- unique(dt, by = c("denomination_sociale", "prenom_nom"), fromLast = TRUE)
  
  # Réinitialiser index
  dt[, row_id := .I]
  
  message(sprintf(
    "[OpenRBE] Données chargées: %d bénéficiaires | %d entreprises | %d PPE",
    nrow(dt),
    uniqueN(dt$denomination_sociale),
    sum(dt$est_ppe_bool, na.rm = TRUE)
  ))
  
  return(dt)
}
