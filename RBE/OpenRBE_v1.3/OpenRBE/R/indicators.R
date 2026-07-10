# =============================================================================
# OpenRBE - Fonctions analytiques et indicateurs
# ITIE Sénégal - R/indicators.R
# =============================================================================

#' Nombre total d'entreprises uniques
#' @param dt data.table RBE
#' @return integer
get_total_companies <- function(dt) {
  data.table::uniqueN(dt$denomination_sociale)
}

#' Nombre total de bénéficiaires effectifs
#' @param dt data.table RBE
#' @return integer
get_total_beneficiaries <- function(dt) {
  nrow(dt)
}

#' Nombre moyen de bénéficiaires par entreprise
#' @param dt data.table RBE
#' @return numeric (arrondi à 2 décimales)
get_average_beneficiaries <- function(dt) {
  if (nrow(dt) == 0) return(0)
  avg <- dt[, .N, by = denomination_sociale][, mean(N)]
  round(avg, 2)
}

#' Nombre total de PPE
#' @param dt data.table RBE
#' @return integer
get_total_ppe <- function(dt) {
  sum(dt$est_ppe_bool, na.rm = TRUE)
}

#' Nombre de nationalités représentées
#' @param dt data.table RBE
#' @return integer
get_total_nationalities <- function(dt) {
  data.table::uniqueN(dt$nationalite[!is.na(dt$nationalite)])
}

#' Nombre de pays de résidence distincts
#' @param dt data.table RBE
#' @return integer
get_total_residence_countries <- function(dt) {
  data.table::uniqueN(dt$pays_residence[!is.na(dt$pays_residence)])
}

#' Distribution par nationalité (top N)
#' @param dt data.table RBE
#' @param top_n entier : nombre de nationalités à retourner
#' @return data.table: nationalite, n
get_nationality_distribution <- function(dt, top_n = 20) {
  res <- dt[!is.na(nationalite), .N, by = nationalite]
  data.table::setorder(res, -N)
  head(res, top_n)
}

#' Distribution régionale
#' @param dt data.table RBE
#' @return data.table: region, n_entreprises, n_beneficiaires
get_regional_distribution <- function(dt) {
  bens  <- dt[!is.na(region), .N, by = region]
  comps <- dt[!is.na(region),
              .(n_entreprises = data.table::uniqueN(denomination_sociale)),
              by = region]
  res <- merge(bens, comps, by = "region", all = TRUE)
  data.table::setnames(res, "N", "n_beneficiaires")
  data.table::setorder(res, -n_beneficiaires)
  res
}

#' Distribution PPE vs non-PPE
#' @param dt data.table RBE
#' @return data.table: statut, n
get_ppe_distribution <- function(dt) {
  n_ppe    <- sum(dt$est_ppe_bool, na.rm = TRUE)
  n_nonppe <- nrow(dt) - n_ppe
  data.table::data.table(
    statut = c("PPE", "Non PPE"),
    n      = c(n_ppe, n_nonppe)
  )
}

#' Distribution des participations (% Action Direct)
#' @param dt data.table RBE
#' @return numeric vector (valeurs non-NA)
get_ownership_distribution <- function(dt) {
  dt$pct_action_direct[!is.na(dt$pct_action_direct)]
}

#' Résumé par entreprise
#' @param dt data.table RBE
#' @return data.table: entreprise, region, n_bens, pct_moyen
get_company_structure <- function(dt) {
  res <- dt[, .(
    region          = data.table::first(region),
    greffe          = data.table::first(greffe),
    n_beneficiaires = .N,
    pct_moyen       = round(mean(pct_action_direct, na.rm = TRUE), 2),
    n_ppe           = sum(est_ppe_bool, na.rm = TRUE)
  ), by = denomination_sociale]
  data.table::setorder(res, -n_beneficiaires)
  res
}

#' Tableau des PPE
#' @param dt data.table RBE
#' @return data.table PPE filtrés
get_ppe_summary <- function(dt) {
  ppe_dt <- dt[est_ppe_bool == TRUE, .(
    prenom_nom,
    denomination_sociale,
    fonction_ppe,
    nom_ppe,
    nationalite,
    pays_residence,
    pct_action_direct,
    pct_voix_direct,
    region
  )]
  data.table::setorder(ppe_dt, denomination_sociale)
  ppe_dt
}

#' Distribution des acquisitions par année
#' @param dt data.table RBE
#' @return data.table: annee, n
get_year_distribution <- function(dt) {
  res <- dt[!is.na(annee_acquisition), .N, by = annee_acquisition]
  data.table::setorder(res, annee_acquisition)
  res
}

#' Chercher les bénéficiaires d'une entreprise
#' @param dt data.table RBE
#' @param company_name Dénomination Sociale
#' @return data.table des bénéficiaires
get_company_beneficiaries <- function(dt, company_name) {
  dt[denomination_sociale == company_name, .(
    prenom_nom,
    nationalite,
    pays_residence,
    pct_action_direct,
    pct_voix_direct,
    est_ppe_bool,
    fonction_ppe,
    nom_ppe,
    date_acquisition
  )]
}
