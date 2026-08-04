// Génère rapport_de_stage.docx à partir du contenu du rapport LaTeX.
// Usage : node build_docx.js
const fs = require("fs");
const {
  Document, Packer, Paragraph, TextRun, ImageRun, Table, TableRow, TableCell,
  WidthType, AlignmentType, HeadingLevel, Footer, PageNumber, TabStopType,
  BorderStyle, ShadingType, LevelFormat, TableOfContents, PageBreak,
  convertMillimetersToTwip,
} = require("docx");

const BLUE = "191970", ORANGE = "E07B39", ROWFILL = "FCE8D7", GREY = "B4B4B4";
const FONT = "Times New Roman";

const run = (text, opts = {}) => new TextRun({ text, font: FONT, size: 24, ...opts });
const para = (children, opts = {}) =>
  new Paragraph({ children: Array.isArray(children) ? children : [children],
                  spacing: { line: 360, after: 160 }, ...opts });
// Paragraphe de corps : gère *italique* simple
const body = (text, opts = {}) => {
  const parts = text.split(/\*([^*]+)\*/);
  const children = parts.map((t, i) => run(t, i % 2 ? { italics: true } : {}));
  return para(children, { alignment: AlignmentType.JUSTIFIED, ...opts });
};
const bullet = (text) => new Paragraph({
  children: [run(text)], numbering: { reference: "puces", level: 0 },
  spacing: { line: 360, after: 80 }, alignment: AlignmentType.JUSTIFIED,
});
const numbered = (text) => new Paragraph({
  children: [run(text)], numbering: { reference: "reco", level: 0 },
  spacing: { line: 360, after: 80 }, alignment: AlignmentType.JUSTIFIED,
});
const h1 = (text) => new Paragraph({
  heading: HeadingLevel.HEADING_1, pageBreakBefore: true,
  alignment: AlignmentType.CENTER, spacing: { after: 240 },
  children: [run(text, { bold: true, size: 32, color: BLUE })],
});
const h2 = (text) => new Paragraph({
  heading: HeadingLevel.HEADING_2, spacing: { before: 200, after: 120 },
  children: [run(text, { bold: true, size: 26, color: BLUE })],
});
const img = (file, type, wPx, hPx) => new ImageRun({
  data: fs.readFileSync(file), type,
  transformation: { width: wPx, height: hPx },
});

const noBorder = { style: BorderStyle.NONE, size: 0, color: "FFFFFF" };
const thin = { style: BorderStyle.SINGLE, size: 4, color: GREY };
const allThin = { top: thin, bottom: thin, left: thin, right: thin };
const allNone = { top: noBorder, bottom: noBorder, left: noBorder, right: noBorder };

const cell = (text, { width, fill, bold, color, align, borders } = {}) => new TableCell({
  width: { size: width, type: WidthType.DXA },
  shading: fill ? { type: ShadingType.CLEAR, fill } : undefined,
  borders: borders || allThin,
  margins: { top: 60, bottom: 60, left: 100, right: 100 },
  children: [new Paragraph({
    alignment: align,
    spacing: { line: 276 },
    children: [run(text, { bold, color, size: 22 })],
  })],
});

// ── Page de garde ────────────────────────────────────────────
const cover = [
  para(run("RÉPUBLIQUE DU SÉNÉGAL", { bold: true, size: 22 }),
       { alignment: AlignmentType.CENTER, spacing: { after: 40 } }),
  para(run("Un Peuple - Un But - Une Foi", { size: 18 }),
       { alignment: AlignmentType.CENTER, spacing: { after: 240 } }),
  new Table({
    width: { size: 9300, type: WidthType.DXA },
    columnWidths: [4650, 4650],
    borders: { ...allNone, insideHorizontal: noBorder, insideVertical: noBorder },
    rows: [new TableRow({ children: [
      new TableCell({
        width: { size: 4650, type: WidthType.DXA }, borders: allNone,
        children: [
          para(img("ANSD.jpg", "jpg", 87, 72), { alignment: AlignmentType.CENTER, spacing: { after: 60 } }),
          para(img("ensae.png", "png", 76, 76), { alignment: AlignmentType.CENTER, spacing: { after: 60 } }),
          para(run("École Nationale de la Statistique", { bold: true, size: 18 }),
               { alignment: AlignmentType.CENTER, spacing: { after: 0 } }),
          para(run("et de l'Analyse Économique Pierre Ndiaye", { bold: true, size: 18 }),
               { alignment: AlignmentType.CENTER, spacing: { after: 0 } }),
        ],
      }),
      new TableCell({
        width: { size: 4650, type: WidthType.DXA }, borders: allNone,
        children: [
          para(run("Présidence de la République", { bold: true, size: 18 }),
               { alignment: AlignmentType.CENTER, spacing: { after: 100 } }),
          para(img("Itie.png", "png", 129, 79), { alignment: AlignmentType.CENTER, spacing: { after: 60 } }),
          para(run("Comité national ITIE Sénégal", { bold: true, size: 18 }),
               { alignment: AlignmentType.CENTER, spacing: { after: 0 } }),
        ],
      }),
    ]})],
  }),
  para(run(""), { spacing: { after: 360 } }),
  // Bandeau titre
  new Paragraph({
    alignment: AlignmentType.CENTER,
    shading: { type: ShadingType.CLEAR, fill: BLUE },
    spacing: { before: 200, after: 0 },
    border: { top: { style: BorderStyle.SINGLE, size: 6, color: "00AEEF" },
              left: { style: BorderStyle.SINGLE, size: 6, color: "00AEEF" },
              bottom: { style: BorderStyle.SINGLE, size: 6, color: "00AEEF" },
              right: { style: BorderStyle.SINGLE, size: 6, color: "00AEEF" } },
    children: [run("RAPPORT DE STAGE", { bold: true, size: 48, color: "FFFFFF" })],
  }),
  para(run(""), { spacing: { after: 120 } }),
  // Cartouche sous-titre
  new Paragraph({
    alignment: AlignmentType.CENTER,
    shading: { type: ShadingType.CLEAR, fill: ROWFILL },
    border: { top: { style: BorderStyle.SINGLE, size: 8, color: BLUE },
              left: { style: BorderStyle.SINGLE, size: 8, color: BLUE },
              bottom: { style: BorderStyle.SINGLE, size: 8, color: BLUE },
              right: { style: BorderStyle.SINGLE, size: 8, color: BLUE } },
    spacing: { after: 360, line: 300 },
    children: [
      run("Appui à la gestion des données du secteur extractif", { size: 26, color: BLUE }),
      new TextRun({ text: "", break: 1 }),
      run("Fiabilisation du Registre des Bénéficiaires Effectifs et analyse du sous-secteur de l'EMAPE par la statistique miroir",
          { size: 26, color: BLUE }),
    ],
  }),
  para([
    run("Stage effectué au sein du "),
    run("Comité national de l'Initiative pour la Transparence dans les Industries Extractives (CN-ITIE)", { bold: true }),
    run(", Service « Gestion des données »"),
  ], { alignment: AlignmentType.CENTER, spacing: { after: 80 } }),
  para(run("Ngor-Almadies, Dakar, du 04 mai au 31 juillet 2026", { italics: true }),
       { alignment: AlignmentType.CENTER, spacing: { after: 360 } }),
  new Table({
    width: { size: 9300, type: WidthType.DXA },
    columnWidths: [4650, 4650],
    borders: { ...allNone, insideHorizontal: noBorder, insideVertical: noBorder },
    rows: [new TableRow({ children: [
      new TableCell({
        width: { size: 4650, type: WidthType.DXA }, borders: allNone,
        children: [
          para(run("Présenté par :", { bold: true }), { spacing: { after: 60 } }),
          para(run("Sié Rachid TRAORÉ"), { spacing: { after: 0 } }),
          para(run("Élève Ingénieur Statisticien Économiste (ISE3)"), { spacing: { after: 0 } }),
          para(run("ENSAE Pierre Ndiaye, Dakar"), { spacing: { after: 0 } }),
        ],
      }),
      new TableCell({
        width: { size: 4650, type: WidthType.DXA }, borders: allNone,
        children: [
          para(run("Encadreur :", { bold: true }), { spacing: { after: 60 } }),
          para(run("M. Fallou DIONE"), { spacing: { after: 0 } }),
          para(run("Gestionnaire de données, CN-ITIE", { italics: true }), { spacing: { after: 120 } }),
          para(run("Supervision :", { bold: true }), { spacing: { after: 60 } }),
          para(run("M. Thaddée Adiouma SECK"), { spacing: { after: 0 } }),
          para(run("Secrétaire Permanent du CN-ITIE", { italics: true }), { spacing: { after: 0 } }),
        ],
      }),
    ]})],
  }),
  para(run(""), { spacing: { after: 300 } }),
  para(run("Année académique 2025-2026", { bold: true, color: BLUE }),
       { alignment: AlignmentType.CENTER }),
  new Paragraph({ children: [new PageBreak()] }),
];

// ── Pages liminaires ─────────────────────────────────────────
const remerciements = [
  h1("Remerciements"),
  body("Je tiens à exprimer ma profonde gratitude à l'ensemble du personnel du Comité national de l'Initiative pour la Transparence dans les Industries Extractives (CN-ITIE) du Sénégal pour la qualité de l'accueil qui m'a été réservé durant ces trois mois de stage."),
  body("Mes remerciements s'adressent en premier lieu à Monsieur Thaddée Adiouma SECK, Secrétaire Permanent du CN-ITIE, pour m'avoir ouvert les portes de l'institution et pour la confiance accordée dans le traitement de données sensibles du secteur extractif."),
  body("Je remercie tout particulièrement Monsieur Fallou DIONE, Gestionnaire de données et encadreur du stage, pour son suivi hebdomadaire rigoureux, ses orientations méthodologiques et la validation attentive de chacun des livrables."),
  body("Ma reconnaissance va également à l'ensemble de l'équipe du Secrétariat Technique du CN-ITIE pour leur disponibilité, ainsi qu'à mon binôme de stage, Rasmané BAMOGO, avec qui les travaux communs sur le Registre des Bénéficiaires Effectifs ont été menés dans un esprit de collaboration exemplaire."),
  body("Enfin, je remercie l'École Nationale de la Statistique et de l'Analyse Économique (ENSAE) Pierre Ndiaye, dont le consortium établi avec le CN-ITIE a rendu possible cette immersion professionnelle."),
];

const avantPropos = [
  h1("Avant-propos"),
  body("Le présent rapport est établi en application de l'article 8 du contrat de stage signé entre le CN-ITIE et le stagiaire, qui dispose qu'à la fin du stage un rapport écrit est soumis à la structure d'accueil. Il rend compte du déroulement du stage effectué du 04 mai au 31 juillet 2026 au service « Gestion des données » du CN-ITIE, des travaux réalisés au regard du cahier des charges, des résultats obtenus, ainsi que des compétences acquises."),
  body("Conformément aux articles 4 et 7 du contrat de stage, les données individuelles traitées durant le stage demeurent confidentielles. Le présent rapport ne restitue que des résultats agrégés et des éléments méthodologiques, à l'exclusion de toute donnée nominative non publique."),
  body("Un état de suivi détaillé des travaux, précisant pour chaque tâche si elle est réalisée, partiellement réalisée ou non réalisée, et assorti de commentaires, figure en annexe."),
];

const sigles = [
  ["AMA", "Autorisation minière artisanale"],
  ["AMSM", "Autorisation minière semi-mécanisée"],
  ["ANSD", "Agence Nationale de la Statistique et de la Démographie"],
  ["BCEAO", "Banque Centrale des États de l'Afrique de l'Ouest"],
  ["BE", "Bénéficiaire effectif"],
  ["CN-ITIE", "Comité national de l'Initiative pour la Transparence dans les Industries Extractives"],
  ["DCSOM", "Direction du Contrôle et de la Surveillance des Opérations Minières"],
  ["DGI", "Direction Générale des Impôts"],
  ["DGMG", "Direction Générale des Mines et de la Géologie"],
  ["DREPM", "Direction régionale de l'Énergie, du Pétrole et des Mines"],
  ["EMAPE", "Exploitation Minière Artisanale et à Petite Échelle"],
  ["ENSAE", "École Nationale de la Statistique et de l'Analyse Économique"],
  ["FARI", "Fiscal Analysis of Resource Industries (modèle FMI)"],
  ["GAFI", "Groupe d'Action Financière"],
  ["GMP", "Groupe Multipartite"],
  ["ISE", "Ingénieur Statisticien Économiste"],
  ["ISIN", "International Securities Identification Number"],
  ["ITIE", "Initiative pour la Transparence dans les Industries Extractives"],
  ["MEPM", "Ministère de l'Énergie, du Pétrole et des Mines"],
  ["OE", "(Programme) Propriété effective / Ownership Engagement"],
  ["PPE", "Personne Politiquement Exposée"],
  ["RBE", "Registre des Bénéficiaires Effectifs"],
  ["RCCM", "Registre du Commerce et du Crédit Mobilier"],
  ["SH", "Système Harmonisé (nomenclature douanière)"],
  ["UE", "Union Européenne"],
];
const siglesSection = [
  h1("Sigles et abréviations"),
  new Table({
    width: { size: 9300, type: WidthType.DXA },
    columnWidths: [2000, 7300],
    borders: { ...allNone, insideHorizontal: noBorder, insideVertical: noBorder },
    rows: sigles.map(([sig, def]) => new TableRow({ children: [
      cell(sig, { width: 2000, bold: true, borders: allNone }),
      cell(def, { width: 7300, borders: allNone }),
    ]})),
  }),
];

const sommaire = [
  h1("Sommaire"),
  new TableOfContents("Sommaire", { hyperlink: true, headingStyleRange: "1-2" }),
];

// ── Fiche synthétique ────────────────────────────────────────
const fiche = [
  ["Structure d'accueil", "CN-ITIE Sénégal, service « Gestion des données »"],
  ["Période", "04 mai - 31 juillet 2026 (3 mois, 12 semaines)"],
  ["Stagiaire", "Sié Rachid TRAORÉ, élève ISE3 (ENSAE Pierre Ndiaye)"],
  ["Binôme", "Rasmané BAMOGO (lot commun RBE)"],
  ["Supervision", "M. Thaddée Adiouma SECK, Secrétaire Permanent"],
  ["Encadreur", "M. Fallou DIONE, Gestionnaire de données"],
  ["Suivi", "Points hebdomadaires (30 min) sur compte rendu d'avancement ; revue formelle de mi-parcours ; présentation finale devant l'équipe"],
  ["Obligations", "Confidentialité des données, scripts reproductibles, sources référencées, validation des livrables avant diffusion"],
];
const ficheTable = new Table({
  width: { size: 9300, type: WidthType.DXA },
  columnWidths: [2800, 6500],
  borders: { top: thin, bottom: thin, left: thin, right: thin,
             insideHorizontal: thin, insideVertical: thin },
  rows: [
    new TableRow({ tableHeader: true, children: [
      cell("Élément", { width: 2800, fill: ORANGE, bold: true, color: "FFFFFF" }),
      cell("Description", { width: 6500, fill: ORANGE, bold: true, color: "FFFFFF" }),
    ]}),
    ...fiche.map(([k, v], i) => new TableRow({ children: [
      cell(k, { width: 2800, fill: i % 2 ? ROWFILL : "FFFFFF" }),
      cell(v, { width: 6500, fill: i % 2 ? ROWFILL : "FFFFFF" }),
    ]})),
  ],
});

// ── Annexe : état de suivi ───────────────────────────────────
const suivi = [
  ["Revue documentaire (Norme ITIE 2023 ex. 2.5, décret 2020-791, diagnostic OE 2024)", "Oui", "Corpus réglementaire constitué et exploité (décrets 2020-791 et 2025-1354, arrêté 1598, codes minier et pétrolier)."],
  ["Note sur la méthode d'analyse miroir", "Oui", "Note méthodologique rédigée (principe, nomenclature SH, variables, précautions d'interprétation)."],
  ["Collecte formulaires ITIE (annexes 1 & 3), RCCM, DGI ; inventaire des sociétés sans déclaration", "Oui", "Croisement RBE / titres miniers (Landfolio, MEPM) / permis / sous-traitants ; fichier des écarts entre registres produit."],
  ["Plateforme RBE relationnelle (tables Entités, Personnes, Relations ; identifiants uniques)", "Oui", "Plateforme OpenRBE développée (Shiny + web autonome, v1.0 à v7) ; schéma relationnel à trois tables avec identifiants uniques mis en place."],
  ["Enrichissement RBE (résidences, statuts PPE, cotation boursière ISIN)", "Oui", "Nettoyage et normalisation réalisés ; champs de résidence, statuts PPE et cotations complétés."],
  ["Premiers travaux EMAPE, cartographie des zones actives (Landfolio)", "Oui", "Situation des titres EMAPE (AMSM/AMA) établie et cartographie des zones actives réalisée."],
  ["Analyse de réseau (chaînes d'actionnariat, détection des structures opaques)", "Oui", "Module réseau intégré à OpenRBE ; visualisation des chaînes d'actionnariat et détection des structures opaques."],
  ["Enquêtes auprès des structures concernées", "Oui", "Enquêtes et échanges menés avec les parties prenantes et les structures concernées."],
  ["Finalisation analyse des risques RBE (GAFI, UE, âges atypiques)", "Oui", "Audit qualité complet et analyse des risques finalisée (croisements GAFI et UE, âges atypiques)."],
  ["Estimation des volumes EMAPE par analyse miroir (2020-2024)", "Oui", "Écart cumulé estimé à 25,4 t (93,6 t importées vs 68,2 t exportées) ; taux moyen de non-déclaration de 27,1 %."],
  ["Cartographie des circuits de commercialisation et des acteurs de la chaîne de valeur", "Oui", "Structure des acheteurs, corridors (Suisse 57 %, Australie 19 %, EAU), obstacles à la traçabilité, manque à gagner estimé."],
  ["Rédaction du rapport RBE final", "Oui", "« Analyse de la qualité des données du RBE 2021-2025 » (version finale) + présentation de restitution."],
  ["Rédaction du rapport EMAPE final", "Oui", "« Rapport analytique EMAPE : flux commerciaux d'or, problématiques de données et statistique miroir » (vf)."],
  ["Dashboard RBE interactif (Power BI)", "Oui", "Réalisé sous la forme de la plateforme web interactive OpenRBE (tableau de bord filtrable, carte, réseau, exports)."],
  ["Intégration des observations et finalisation", "Oui", "Versions successives des rapports et de la plateforme intégrant les observations de l'encadreur."],
  ["__SECTION__", "Travaux complémentaires (hors cahier des charges)", ""],
  ["Consolidation des données des rapports ITIE 2013-2024", "Oui", "Bases production, exportations, flux financiers, paiements sociaux, emplois, contribution, hydrocarbures ; taux de change BCEAO."],
  ["Analyse des paiements sociaux", "Oui", "Rapport R Markdown reproductible + carte de répartition géographique (QGIS)."],
  ["Traitement des états financiers des entreprises", "Oui", "Plus de 75 liasses DGI saisies (2020, 2022-2024) ; compte de résultat agrégé multi-exercices."],
  ["Comparaison prix des minerais exportés vs cours mondiaux", "Oui", "Base valeurs unitaires ITIE 2020-2024 vs Pink Sheet / CMO (Banque mondiale)."],
  ["Initiation à la modélisation financière extractive (FARI, Sangomar, SGO)", "Oui", "Cadre FARI étudié, maquette Sangomar explorée, projet de rapport sur la fiscalité de Sabodala engagé ; réunion LAREM-CN-ITIE du 02/07/2026."],
  ["Participation à la vie institutionnelle", "Oui", "Réunions de coordination du Secrétariat Technique, comptes rendus."],
  ["Participation au forum national sur la gouvernance du secteur extractif au Sénégal", "Oui", "Participation aux échanges multipartites (État, entreprises, société civile) sur la transparence du secteur."],
  ["Rédaction du rapport de stage (article 8 du contrat)", "Oui", "Présent document."],
];
const W1 = 3400, W2 = 1500, W3 = 4400;
const suiviRows = [
  new TableRow({ tableHeader: true, children: [
    cell("Travaux", { width: W1, fill: ORANGE, bold: true, color: "FFFFFF", align: AlignmentType.CENTER }),
    cell("Réalisé", { width: W2, fill: ORANGE, bold: true, color: "FFFFFF", align: AlignmentType.CENTER }),
    cell("Commentaire", { width: W3, fill: ORANGE, bold: true, color: "FFFFFF", align: AlignmentType.CENTER }),
  ]}),
];
let zebra = 0;
for (const [t, r, c] of suivi) {
  if (t === "__SECTION__") {
    suiviRows.push(new TableRow({ children: [
      new TableCell({
        columnSpan: 3, borders: allThin,
        width: { size: W1 + W2 + W3, type: WidthType.DXA },
        shading: { type: ShadingType.CLEAR, fill: ROWFILL },
        margins: { top: 60, bottom: 60, left: 100, right: 100 },
        children: [new Paragraph({ children: [run(r, { bold: true, color: BLUE, size: 22 })] })],
      }),
    ]}));
    zebra = 0;
    continue;
  }
  const fill = zebra % 2 ? ROWFILL : "FFFFFF";
  suiviRows.push(new TableRow({ children: [
    cell(t, { width: W1, fill }),
    cell(r, { width: W2, fill, align: AlignmentType.CENTER }),
    cell(c, { width: W3, fill }),
  ]}));
  zebra++;
}
const suiviTable = new Table({
  width: { size: W1 + W2 + W3, type: WidthType.DXA },
  columnWidths: [W1, W2, W3],
  borders: { top: thin, bottom: thin, left: thin, right: thin,
             insideHorizontal: thin, insideVertical: thin },
  rows: suiviRows,
});

// ── Corps du rapport ─────────────────────────────────────────
const corps = [
  h1("Introduction"),
  body("Dans le cadre du consortium établi entre l'École Nationale de la Statistique et de l'Analyse Économique (ENSAE) Pierre Ndiaye et le Comité national de l'Initiative pour la Transparence dans les Industries Extractives (CN-ITIE) du Sénégal, deux élèves en dernière année du cycle Ingénieur Statisticien Économiste ont été accueillis en stage pour une durée de trois mois. J'ai ainsi effectué, du 04 mai au 31 juillet 2026, un stage au service « Gestion des données » du CN-ITIE, sous la supervision du Secrétaire Permanent, Monsieur Thaddée Adiouma SECK, et l'encadrement technique du Gestionnaire de données, Monsieur Fallou DIONE."),
  body("Le stage s'inscrit dans un contexte de renforcement structurel des capacités d'analyse, de contrôle et de gouvernance du secteur extractif sénégalais. Le cahier des charges qui l'encadre lui assigne deux objectifs principaux :"),
  bullet("fiabiliser et enrichir le Registre des Bénéficiaires Effectifs (RBE) des sociétés extractives, en assurant une conformité renforcée avec l'exigence 2.5 de la Norme ITIE 2023 ;"),
  bullet("produire une base analytique robuste sur les Exploitations Minières Artisanales et à Petite Échelle (EMAPE), incluant l'estimation des volumes de production par la méthode des statistiques miroir et la cartographie des circuits de commercialisation et des acteurs de la chaîne de valeur."),
  body("Le dispositif de stage reposait sur un lot commun obligatoire consacré au registre des bénéficiaires effectifs, mené conjointement avec mon binôme M. Rasmané BAMOGO durant les six premières semaines, puis sur un lot thématique individuel consacré à l'exploitation minière artisanale, mené en parallèle à compter de la troisième semaine. Le stage était explicitement « orienté résultats ». Les livrables constituaient des obligations contractuelles, tout choix méthodologique devait être justifié, les scripts documentés et reproductibles, et les sources systématiquement référencées."),
  body("Le présent rapport s'articule en quatre parties. La première présente la structure d'accueil et le cadre du stage. La deuxième détaille les travaux menés sur le Registre des Bénéficiaires Effectifs, à savoir l'audit de qualité des données 2021-2025 et le développement de la plateforme de consultation *OpenRBE*. La troisième expose les travaux sur le sous-secteur de l'EMAPE et l'application de la méthode des statistiques miroir aux flux d'or 2020-2024. La quatrième restitue les travaux transverses d'appui au service, puis dresse le bilan du stage (résultats, difficultés, compétences acquises et recommandations)."),

  h1("Présentation de la structure d'accueil et cadre du stage"),
  h2("Le Comité national ITIE du Sénégal"),
  body("L'Initiative pour la Transparence dans les Industries Extractives (ITIE) est la norme mondiale de référence pour la gouvernance transparente et redevable des ressources pétrolières, gazières et minières. Le Sénégal, pays de mise en œuvre, s'appuie sur un Comité national créé par le décret n° 2013-881 du 20 juin 2013, abrogé et remplacé par le décret n° 2021-1145 du 7 septembre 2021 fixant les règles de son organisation et de son fonctionnement. Son siège est situé à Ngor-Almadies, sur le site dit « IPRES », à Dakar."),
  body("Le CN-ITIE est une structure tripartite regroupant des représentants du Gouvernement, des entreprises extractives et de la société civile. Il est chargé de superviser la mise en œuvre de la Norme ITIE au Sénégal, notamment à travers :"),
  bullet("la collecte et la réconciliation des données sur les revenus du secteur extractif, c'est-à-dire les flux financiers entre les entreprises et l'État ;"),
  bullet("la divulgation des informations relatives à la propriété effective des entreprises extractives ;"),
  bullet("la production des rapports annuels ITIE et le renforcement de la transparence dans la gestion des ressources minières, pétrolières et gazières."),
  body("Ses activités quotidiennes sont assurées par un Secrétariat Technique placé sous l'autorité du Groupe Multipartite. Le service « Gestion des données », au sein duquel le stage s'est déroulé, est responsable de la collecte, de la structuration, du contrôle qualité et de la valorisation des données du périmètre ITIE."),
  h2("Cadre contractuel et organisation du stage"),
  body("Le stage a été formalisé par un contrat signé avec le CN-ITIE, complété par un cahier des charges détaillé. Les principaux éléments du dispositif sont récapitulés ci-dessous."),
  ficheTable,
  para(run("Tableau 1. Fiche synthétique du stage", { bold: true, size: 20 }),
       { alignment: AlignmentType.CENTER, spacing: { before: 80, after: 200 } }),
  body("Le calendrier prévisionnel du cahier des charges structurait le stage en quatre phases, le cadrage et la collecte en semaines 1 et 2, la structuration des bases en semaines 3 à 6, l'analyse et la modélisation en semaines 7 à 9, puis les livrables finaux en semaines 10 à 12. Les travaux qui m'étaient assignés couvraient le lot commun RBE et le lot thématique EMAPE ; la modélisation économétrique des coûts de production relevait du lot de mon binôme."),

  h1("Travaux sur le Registre des Bénéficiaires Effectifs"),
  body("L'exigence 2.5 de la Norme ITIE 2023 impose la divulgation de l'identité des bénéficiaires effectifs de toutes les sociétés extractives détentrices de licences actives. Au Sénégal, ce cadre est décliné par le décret n° 2020-791 du 19 mars 2020 et ses modificatifs, dont le récent décret n° 2025-1354 relatif au registre des bénéficiaires effectifs. Le diagnostic conduit en 2024 dans le cadre du programme de divulgation de la propriété effective avait révélé des lacunes importantes : sociétés sans déclaration, qualité insuffisante des données, absence d'identifiants communs entre registres administratifs. Les travaux RBE du stage visaient à objectiver puis résorber ces lacunes."),
  h2("Revue documentaire et collecte"),
  body("La phase de cadrage a consisté à constituer et exploiter un corpus réglementaire et méthodologique comprenant la Norme ITIE 2023 en son exigence 2.5, le décret n° 2020-791 et ses modificatifs, le décret n° 2025-1354, l'arrêté ministériel n° 1598 relatif au formulaire de déclaration des bénéficiaires effectifs et les codes minier et pétrolier, ainsi que le diagnostic précité de 2024 et le projet d'étude « Bénéficiaires effectifs » du Sénégal."),
  body("La collecte a ensuite mobilisé plusieurs sources croisées, dont la base RBE existante du CN-ITIE pour les exercices 2021 à 2025, les annexes 1 et 3 des formulaires de déclaration ITIE, la base des titres miniers du Ministère de l'Énergie, du Pétrole et des Mines extraite du système Landfolio, le registre des permis, la liste des sous-traitants ainsi que les états de souscription. Ce croisement a permis de dresser l'inventaire des sociétés titulaires de titres actifs sans déclaration de bénéficiaires effectifs, matérialisé par un fichier dédié recensant les entreprises présentes dans le RBE mais absentes des autres registres, et réciproquement."),
  h2("Audit de la qualité des données du RBE 2021-2025"),
  body("Le premier livrable majeur du lot RBE est le rapport d'analyse de la qualité des données du registre, élaboré conjointement avec mon binôme et validé dans sa version finale. La base auditée couvre cinq exercices, de 2021 à 2025, et recense 628 enregistrements de bénéficiaires effectifs pour 317 entreprises réparties dans neuf régions. Les principaux constats sont les suivants :"),
  bullet("Complétude. Sur 7 536 cellules attendues, 23 % sont manquantes. Les six variables d'identification, à savoir la région, la dénomination sociale, le greffe, le prénom et le nom, la nationalité et l'année, sont intégralement renseignées, mais les variables liées au statut de personne politiquement exposée concentrent les déficits les plus graves, avec « Nom PPE » absent dans 97,1 % des cas et « Est une PPE » dans 85,2 %. Les variables financières sont également lacunaires, avec 27,1 % des pourcentages d'actions et 41,9 % des droits de vote manquants ;"),
  bullet("Doublons. 12 enregistrements en double, soit 1,9 % des observations, dont 2 cas présentant des valeurs financières contradictoires conduisant à des totaux de participation supérieurs à 100 % ;"),
  bullet("Erreurs de saisie. 547 enregistrements affectés, dont 545 contenant un code binaire dans le champ textuel « Fonction PPE » et 14 un nom de pays dans le champ « Est une PPE » ;"),
  bullet("Cohérences structurelles. Entreprises dont la somme des participations dépasse ou n'atteint pas 100 %, hétérogénéités régionales fortes, Diourbel et Kaolack affichant 100 % de valeurs manquantes sur les variables financières et de personnes politiquement exposées ;"),
  bullet("Couverture. Analyse croisée des statuts de déclaration par type et statut de titre minier, par région, par substance et par année, et identification des entreprises présentes dans le RBE uniquement."),
  body("Ce diagnostic, décliné en tableaux et cartographies croisant variable et exercice puis variable et région, fonde les recommandations adressées au CN-ITIE, notamment la fiabilisation du formulaire de déclaration, des contrôles de saisie bloquants, la priorité de relance sur les variables financières et de personnes politiquement exposées, et le dédoublonnage systématique. Il a ensuite permis de conduire l'analyse des risques prévue par le programme de divulgation de la propriété effective, portant sur les âges atypiques et les croisements avec les listes du Groupe d'Action Financière et de l'Union européenne, une fois les variables concernées fiabilisées et complétées."),
  h2("Développement de la plateforme OpenRBE"),
  body("Le cahier des charges prévoyait la mise en place d'une plateforme RBE relationnelle et d'un tableau de bord interactif. Ce volet a été réalisé sous la forme d'OpenRBE, une application de consultation et de valorisation du RBE développée de manière itérative, des versions v1.0 à v7 puis des versions web successives jusqu'à la version de livraison, en concertation avec l'encadreur dont les observations étaient intégrées à chaque itération."),
  body("Deux déclinaisons complémentaires ont été produites :"),
  bullet("une application R Shiny modulaire, comportant des modules de tableau de bord, de recherche, de cartographie, de réseau et de suivi des personnes politiquement exposées, avec une bibliothèque d'indicateurs et de graphiques ;"),
  bullet("une application web autonome générée par un script Python documenté, qui nettoie et normalise la base RBE 2021-2025, en recodant les champs des personnes politiquement exposées, en bornant les pourcentages, en harmonisant les nationalités et les pays de résidence et en extrayant les années, puis produit une page interactive unique, avec tableau de bord filtrable, visualisation des réseaux d'actionnariat et export de données, déployable sans dépendance serveur."),
  body("Le module « réseau » de la plateforme permet la visualisation des chaînes d'actionnariat entreprise-bénéficiaire et la détection des structures de contrôle opaques prévue par le programme de divulgation de la propriété effective. Le schéma relationnel cible à trois tables normalisées des entités, des personnes et des relations, doté d'identifiants uniques et permettant le calcul des participations indirectes cumulées, a été mis en place, de même que l'enrichissement par les pays de résidence, les statuts de personne politiquement exposée et les cotations boursières prévu au cahier des charges."),
  body("Une présentation de synthèse du RBE, sous la forme d'un support de treize diapositives, a par ailleurs été produite pour la restitution institutionnelle des travaux."),

  h1("Travaux sur l'EMAPE et statistique miroir"),
  body("Le lot thématique individuel portait sur le sous-secteur de l'Exploitation Minière Artisanale et à Petite Échelle, dont la contribution à l'économie extractive demeure structurellement sous-estimée dans les statistiques officielles. L'objectif était double, documenter l'état des lieux institutionnel et statistique du sous-secteur, puis estimer les volumes d'or non déclarés par la méthode des statistiques miroir sur la période 2020-2024, en cohérence avec les exigences 6.1 et 6.3 de la Norme ITIE 2023."),
  h2("Note méthodologique sur l'analyse miroir"),
  body("Une note méthodologique a d'abord été rédigée pour justifier le choix de la méthode, conformément à l'obligation de justification des choix méthodologiques du cahier des charges. L'analyse miroir consiste à confronter, pour un même flux de marchandises, ici l'or relevant notamment de la position 7108 du Système harmonisé, les exportations déclarées par le pays d'origine avec les importations déclarées par les pays partenaires. L'écart systématique entre les deux flux, corrigé des conventions d'enregistrement, valorisation coût-assurance-fret ou franco à bord, année d'enregistrement, pays d'origine ou de provenance, constitue un indicateur des exportations non déclarées et, indirectement, de la production échappant au circuit officiel. La note documente également la nomenclature douanière utilisée, les variables retenues et les précautions d'interprétation."),
  h2("Constitution de la base et estimation des écarts"),
  body("La base analytique a été constituée à partir de trois corpus complémentaires : les statistiques du commerce international de la base UN Comtrade, complétées par des données de type Trade Data Monitor ; les données nationales, à savoir les exportations déclarées côté Sénégal, les rapports ITIE, les données des directions en charge des mines et du contrôle des opérations minières et les rapports annuels de la Banque Centrale des États de l'Afrique de l'Ouest de 2020 à 2023 ; et les données de production EMAPE déclarées au CN-ITIE. Les scripts de traitement ont été développés sous R, de façon documentée et reproductible."),
  body("Les principaux résultats de l'analyse, consignés dans le rapport analytique final, sont les suivants :"),
  bullet("un écart cumulé de 25,4 tonnes entre les importations d'or déclarées par les pays partenaires, soit 93,6 tonnes, et les exportations déclarées côté Sénégal, soit 68,2 tonnes, sur 2020-2024, source d'une perte fiscale importante pour l'État ;"),
  bullet("un taux moyen de non-déclaration de 27,1 % sur la période, avec une forte variabilité annuelle, de 50,4 % en 2020 à 4,6 % en 2024, dont l'interprétation requiert prudence ;"),
  bullet("une production EMAPE déclarée dérisoire, 62 kilogrammes en 2023, 88 en 2024 et 23 en 2025, pour 12 entreprises déclarantes seulement sur environ 150 autorisations actives, révélant un angle mort statistique majeur ;"),
  bullet("une concentration géographique persistante des importations sur deux corridors, la Suisse avec 57 % des flux cumulés et l'Australie avec 19 %, et une trajectoire préoccupante du corridor des Émirats Arabes Unis, en progression jusqu'en 2023 puis en disparition totale en 2024 ;"),
  bullet("une triangulation des estimations miroir avec les données de production déclarées et une vue multidimensionnelle du manque à gagner pour l'État en redevances, fiscalité et devises."),
  h2("État des lieux du sous-secteur et circuits de commercialisation"),
  body("Le rapport analytique documente par ailleurs le cadre institutionnel de l'EMAPE, placé sous la tutelle du Ministère de l'Énergie, du Pétrole et des Mines, avec les rôles respectifs des directions nationales chargées des mines et du contrôle des opérations minières, des directions régionales, et la rétrogradation en 2024 de la direction dédiée à l'exploitation artisanale au rang de division. Il documente aussi le cadre réglementaire, avec les régimes d'autorisation minière artisanale et semi-mécanisée du Code minier de 2016, les cartes d'orpailleur et les couloirs d'orpaillage de Tambacounda et de Kédougou, ainsi que la situation des titres EMAPE établie à partir de la base des titres miniers."),
  body("La cartographie des circuits de commercialisation a été établie, couvrant la structure des acheteurs de la production artisanale, comptoirs d'achat, collecteurs, négociants et exportateurs, les corridors d'exportation et les acteurs de la chaîne de valeur, avec identification des obstacles institutionnels, techniques, statistiques et douaniers qui limitent la transparence du sous-secteur, au premier rang desquels l'informalité, les défaillances des comptoirs, l'absence de base centralisée, la faible traçabilité et la fragmentation institutionnelle entre les administrations minières, douanières et statistiques. Les enquêtes prévues auprès des structures concernées ont été conduites, en complément de l'exploitation de la littérature disponible, notamment les études SWISSAID, et la cartographie des zones actives a été établie à partir de la base des titres miniers."),
  body("Le rapport se conclut par des recommandations de renforcement des mécanismes de traçabilité et de gouvernance statistique du sous-secteur, en cohérence avec la Norme ITIE 2023."),

  h1("Travaux transverses et activités complémentaires"),
  body("Au-delà des deux lots contractuels, le stage a donné lieu à plusieurs travaux d'appui au service « Gestion des données », qui ont enrichi la maîtrise du périmètre ITIE."),
  h2("Consolidation des données des rapports ITIE 2013-2024"),
  body("Les données publiées dans les rapports ITIE successifs, de 2013 à 2024, ont été extraites et consolidées en bases exploitables couvrant la production et les exportations par substance, les flux financiers, les paiements sociaux, les emplois, la contribution du secteur extractif au budget de l'État et les données hydrocarbures, complétées par une série des taux de change du dollar en franc CFA publiée par la Banque Centrale des États de l'Afrique de l'Ouest. De petits scripts Python ont été écrits pour découper et structurer les fichiers volumineux. Ces bases alimentent notamment l'analyse des exportations aurifères 2020-2024 utilisée dans le lot EMAPE."),
  h2("Analyse des paiements sociaux"),
  body("Une analyse statistique des paiements sociaux des entreprises extractives a été réalisée sous R Markdown, sous la forme d'un rapport reproductible avec tableaux et graphiques par année, par entreprise et par région, accompagnée d'une carte de répartition géographique élaborée sous QGIS. Ce travail met en évidence la concentration des paiements sociaux et leur évolution sur la période récente."),
  h2("Traitement des états financiers des entreprises"),
  body("En appui au lot de modélisation des coûts, j'ai contribué à la collecte et à la saisie structurée des états financiers des entreprises du périmètre ITIE, à partir des liasses fiscales de la Direction Générale des Impôts pour les exercices 2020, 2022, 2023 et 2024, soit plus de 75 états financiers traités, aboutissant à un compte de résultat agrégé multi-exercices par entreprise."),
  h2("Comparaison des prix des minerais exportés"),
  body("Une base de comparaison entre les valeurs unitaires des exportations ITIE de 2020 à 2024 et les cours mondiaux de référence publiés par la Banque mondiale a été constituée afin de détecter d'éventuelles anomalies de valorisation des minerais exportés."),
  h2("Initiation à la modélisation financière extractive"),
  body("Dans le prolongement des termes de référence du CN-ITIE sur la modélisation financière des projets extractifs, je me suis initié au cadre d'analyse fiscale des industries extractives du Fonds Monétaire International, dit FARI, et aux modèles financiers sectoriels du Natural Resource Governance Institute pour l'or et le pétrole. Une maquette de modélisation du projet pétrolier Sangomar a été explorée, ainsi qu'un projet de rapport sur l'impact du régime fiscal minier sur les recettes publiques appliqué à la convention minière de Sabodala. J'ai également participé à la réunion d'échange entre le Laboratoire de recherches économiques et monétaires et le CN-ITIE sur la modélisation financière du projet Sangomar, tenue le 2 juillet 2026. Cette initiation, menée à bien en fin de stage, ouvre la voie à des travaux de modélisation plus approfondis."),
  h2("Vie institutionnelle"),
  body("J'ai enfin pris part aux réunions de coordination du Secrétariat Technique, consacrées au plan de trimestre, à la préparation du rapport ITIE 2025 et au suivi-évaluation, et contribué à l'audit du RBE au regard du nouveau décret n° 2025-1354. J'ai également participé au forum national sur la gouvernance du secteur extractif au Sénégal, temps fort d'échanges entre l'État, les entreprises et la société civile qui m'a permis de situer les travaux du stage dans le débat public sur la transparence du secteur."),

  h1("Bilan du stage"),
  h2("Synthèse des réalisations au regard du cahier des charges"),
  body("Le tableau en annexe détaille, tâche par tâche, l'état de réalisation des travaux prévus au contrat de stage et au cahier des charges. En synthèse :"),
  bullet("l'ensemble des travaux des lots RBE et EMAPE est réalisé, de l'audit de qualité du registre 2021-2025 à la plateforme OpenRBE avec son schéma relationnel, son module de réseau et son analyse des risques, en passant par l'estimation des volumes par la statistique miroir, la cartographie des zones actives et des circuits de commercialisation, les enquêtes auprès des structures concernées et les rapports finaux ;"),
  bullet("les travaux complémentaires sont également réalisés, de la consolidation des données des rapports ITIE 2013-2024 à l'initiation à la modélisation financière extractive, qui ouvre un prolongement naturel de la collaboration."),
  h2("Difficultés rencontrées"),
  body("Les principales difficultés ont été de trois ordres. D'abord, la qualité des données sources. La carence quasi totale des variables sur les personnes politiquement exposées et l'hétérogénéité des saisies ont contraint à réorienter une partie de l'effort analytique vers l'audit et le nettoyage. Ensuite, l'absence de base de données consolidées sur le secteur, qui a imposé de reconstituer l'information à partir de sources dispersées, rapports, registres administratifs et fichiers épars, avant toute analyse. Enfin, la contrainte temporelle d'un stage de douze semaines orienté résultats, qui a imposé des arbitrages entre profondeur méthodologique et couverture des lots, arbitrages systématiquement validés lors des points hebdomadaires."),
  h2("Compétences acquises"),
  body("Ce stage m'a permis de mettre en pratique et de consolider :"),
  bullet("des compétences statistiques et économétriques appliquées, de l'audit de qualité de données à l'analyse de flux commerciaux, en passant par la statistique miroir et la triangulation de sources ;"),
  bullet("des compétences techniques en R, en Python, en Excel avancé, en QGIS et en visualisation de réseaux, du traitement de données aux applications interactives et aux scripts de construction de la plateforme ;"),
  bullet("des compétences sectorielles sur la Norme ITIE 2023, la propriété effective et la lutte anti-blanchiment, la gouvernance minière et pétrolière sénégalaise, la fiscalité extractive et la modélisation financière ;"),
  bullet("des compétences professionnelles, du travail en binôme et en équipe multipartite à la restitution devant des non-statisticiens, en passant par la gestion de livrables contractuels sous contrainte de confidentialité."),
  h2("Recommandations"),
  body("Au terme du stage, les recommandations suivantes sont formulées à l'attention du CN-ITIE :"),
  numbered("Fiabiliser la chaîne de collecte du RBE, par un formulaire à contrôles bloquants, des champs obligatoires sur les personnes politiquement exposées, un dédoublonnage à la saisie et des identifiants uniques partagés avec le registre du commerce, l'administration fiscale et le système Landfolio ;"),
  numbered("Pérenniser et institutionnaliser OpenRBE, en assurant l'hébergement, la gestion des utilisateurs et des exports, la mise à jour administrée des données et la formalisation du schéma Entités-Personnes-Relations pour le calcul des participations indirectes ;"),
  numbered("Systématiser l'analyse miroir comme outil de veille annuelle sur les flux d'or, en lien avec les douanes, l'agence nationale de la statistique et la banque centrale ;"),
  numbered("Renforcer la statistique du sous-secteur EMAPE, avec une base centralisée des comptoirs et des déclarations de production, un couplage avec les données satellitaires et les titres Landfolio et des enquêtes de terrain régulières à Kédougou ;"),
  numbered("Poursuivre la montée en charge sur la modélisation financière selon le cadre FARI, pour éclairer les négociations et le suivi des projets Sangomar et Sabodala."),

  h1("Conclusion"),
  body("Ce stage de trois mois au service « Gestion des données » du CN-ITIE aura été une immersion complète dans la gouvernance des données du secteur extractif sénégalais. Les deux missions contractuelles ont abouti à des livrables concrets, à savoir un diagnostic chiffré et actionnable de la qualité du Registre des Bénéficiaires Effectifs, une plateforme de consultation interactive du RBE, et une première estimation rigoureuse, par la statistique miroir, des flux d'or non déclarés issus de l'EMAPE, soit un écart cumulé de 25,4 tonnes sur 2020-2024 dont la seule mise en évidence justifie le renforcement des dispositifs de traçabilité."),
  body("Au-delà des livrables, le stage a confirmé l'apport du profil d'ingénieur statisticien économiste dans une institution de transparence, celui de transformer des données administratives imparfaites en connaissances utiles à la décision publique. La poursuite de la modélisation financière extractive et l'actualisation régulière des outils livrés tracent une feuille de route claire pour la suite de la collaboration entre le CN-ITIE et l'ENSAE, et nourriront directement mon mémoire de fin d'études."),

  h1("Annexe État de suivi des travaux"),
  suiviTable,
];

// ── Document ─────────────────────────────────────────────────
const footer = new Footer({
  children: [new Paragraph({
    tabStops: [
      { type: TabStopType.CENTER, position: 4650 },
      { type: TabStopType.RIGHT, position: 9300 },
    ],
    border: { top: { style: BorderStyle.SINGLE, size: 4, color: "000000" } },
    children: [
      run("Sié Rachid TRAORÉ, ISE3 (ENSAE-DAKAR)", { size: 14 }),
      new TextRun({ text: "\t{ ", font: FONT, size: 14, bold: true }),
      new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 14, bold: true }),
      new TextRun({ text: " }", font: FONT, size: 14, bold: true }),
      run("\tRapport de stage CN-ITIE, 2026", { size: 14 }),
    ],
  })],
});

const doc = new Document({
  styles: { default: { document: { run: { font: FONT, size: 24 } } } },
  numbering: {
    config: [
      { reference: "puces",
        levels: [{ level: 0, format: LevelFormat.BULLET, text: "•",
                   style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] },
      { reference: "reco",
        levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.",
                   style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] },
    ],
  },
  features: { updateFields: true },
  sections: [{
    properties: {
      page: {
        margin: {
          top: convertMillimetersToTwip(25), bottom: convertMillimetersToTwip(25),
          left: convertMillimetersToTwip(30), right: convertMillimetersToTwip(25),
        },
      },
    },
    footers: { default: footer },
    children: [...cover, ...remerciements, ...avantPropos, ...siglesSection, ...sommaire, ...corps],
  }],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync("rapport_de_stage.docx", buf);
  console.log("rapport_de_stage.docx écrit,", buf.length, "octets");
});
