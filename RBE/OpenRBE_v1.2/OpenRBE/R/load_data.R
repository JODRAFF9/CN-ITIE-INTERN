# =============================================================================
# OpenRBE - Chargement et nettoyage des données RBE  v1.2
# Les NULL/NA sont des valeurs manquantes — affichées "Non renseigné"
# ITIE Sénégal - R/load_data.R
# =============================================================================

load_rbe_data <- function(path = "data/rbe_data.xlsx") {

  if (!file.exists(path)) stop(paste("Fichier introuvable:", path))

  raw <- readxl::read_excel(path, sheet = "Feuil1", skip = 1, col_names = TRUE)
  dt  <- data.table::as.data.table(raw)

  # Renommage des colonnes
  data.table::setnames(dt, old = names(dt), new = c(
    "region", "denomination_sociale", "prenom_nom", "date_acquisition",
    "pct_action_direct", "pct_voix_direct", "nationalite", "pays_residence",
    "est_ppe", "fonction_ppe", "nom_ppe", "greffe", "regions"
  ))

  # Suppression lignes sans entreprise ou étiquettes d'années
  dt <- dt[!is.na(denomination_sociale)]
  dt <- dt[!grepl("^\\d{4}$", as.character(denomination_sociale))]
  dt <- dt[!grepl("^Registre", as.character(denomination_sociale))]

  # Nettoyage des colonnes texte — NA réels
  cols_char <- c("region","denomination_sociale","prenom_nom","nationalite",
                 "pays_residence","greffe","regions","fonction_ppe","nom_ppe")
  dt[, (cols_char) := lapply(.SD, function(x) {
    v <- stringr::str_trim(as.character(x))
    v[v %in% c("NA","nan","NaN","NULL","Inf","-Inf","","0")] <- NA_character_
    v
  }), .SDcols = cols_char]

  # Harmonisation casse
  dt[, nationalite    := stringr::str_to_upper(stringr::str_trim(nationalite))]
  dt[, pays_residence := stringr::str_to_upper(stringr::str_trim(pays_residence))]
  dt[, region         := stringr::str_to_title(stringr::str_trim(region))]

  # Harmonisation "SÉNÉGAL" vs "SENEGAL"
  dt[nationalite    == "SENEGAL", nationalite    := "SÉNÉGAL"]
  dt[pays_residence == "SENEGAL", pays_residence := "SÉNÉGAL"]

  # Colonne PPE booléenne robuste
  dt[, est_ppe_bool := FALSE]
  dt[!is.na(est_ppe) & !(as.character(est_ppe) %in% c("0","NA","nan","FALSE","false")),
     est_ppe_bool := TRUE]

  # Nettoyage fonction_ppe
  dt[!is.na(fonction_ppe) & fonction_ppe %in% c("0","1"),
     fonction_ppe := NA_character_]

  # Pourcentages numériques — plafonner à 100
  dt[, pct_action_direct := suppressWarnings(as.numeric(pct_action_direct))]
  dt[, pct_voix_direct   := suppressWarnings(as.numeric(pct_voix_direct))]
  dt[!is.na(pct_action_direct) & pct_action_direct > 100, pct_action_direct := 100]
  dt[!is.na(pct_voix_direct)   & pct_voix_direct   > 100, pct_voix_direct   := 100]
  dt[!is.na(pct_action_direct) & pct_action_direct < 0,   pct_action_direct := NA_real_]
  dt[!is.na(pct_voix_direct)   & pct_voix_direct   < 0,   pct_voix_direct   := NA_real_]

  # Dates
  dt[, date_acquisition := suppressWarnings(
    as.POSIXct(as.character(date_acquisition), format = "%Y-%m-%d %H:%M:%OS")
  )]
  dt[, annee_acquisition := data.table::year(date_acquisition)]

  # Déduplication souple
  dt <- unique(dt, by = c("denomination_sociale", "prenom_nom"), fromLast = TRUE)
  dt[, row_id := .I]

  n_ppe    <- sum(dt$est_ppe_bool, na.rm = TRUE)
  n_pct_na <- sum(is.na(dt$pct_action_direct))

  message(sprintf(
    "[OpenRBE] %d bénéficiaires | %d entreprises | %d PPE | %d participations non renseignées",
    nrow(dt), data.table::uniqueN(dt$denomination_sociale), n_ppe, n_pct_na
  ))

  return(dt)
}
