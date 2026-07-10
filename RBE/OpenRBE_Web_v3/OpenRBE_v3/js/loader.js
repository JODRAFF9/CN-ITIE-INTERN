/* =============================================================
   OpenRBE v3 — loader.js
   Lecture du fichier Excel RBE-2021-A-2025.xlsx via SheetJS
   Appelé au chargement, expose window.DB (tableau de records)
============================================================= */

const EXCEL_PATH = 'data/RBE-2021-A-2025.xlsx';

/* ── Helpers nettoyage ── */
function cleanStr(v) {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return ['nan','NA','None','NaN','','0'].includes(s) ? null : s;
}

function isPPE(v) {
  if (v === null || v === undefined) return false;
  const s = String(v).trim();
  return !['0','NA','nan','FALSE','false','','None','NaN'].includes(s);
}

function parseDate(v) {
  if (!v) return null;
  if (v instanceof Date) return v;
  // SheetJS retourne souvent un nombre série Excel
  if (typeof v === 'number') {
    const d = new Date(Math.round((v - 25569) * 86400 * 1000));
    return isNaN(d.getTime()) ? null : d;
  }
  const d = new Date(v);
  return isNaN(d.getTime()) ? null : d;
}

function fmtDate(d) {
  if (!d) return null;
  const dd = String(d.getDate()).padStart(2,'0');
  const mm = String(d.getMonth()+1).padStart(2,'0');
  return `${dd}/${mm}/${d.getFullYear()}`;
}

function parseNum(v) {
  const n = parseFloat(v);
  return isNaN(n) ? null : n;
}

/* ── Harmonisation ── */
function harmonize(s, type) {
  if (!s) return s;
  if (type === 'upper') {
    s = s.toUpperCase();
    s = s.replace(/^SENEGAL$/, 'SÉNÉGAL').replace(/^EGYPT$/, 'ÉGYPTE');
    return s;
  }
  if (type === 'title') return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
  return s;
}

/* ── Traitement d'une feuille SheetJS ── */
function processSheet(sheet) {
  // Lire depuis ligne 2 (index 1) = headers réels
  const rawRows = XLSX.utils.sheet_to_json(sheet, {
    header: 1,
    defval: null,
    raw: true,
  });

  // Trouver la ligne header (contient "Denomination Sociale")
  let headerIdx = -1;
  for (let i = 0; i < Math.min(rawRows.length, 5); i++) {
    if (rawRows[i] && rawRows[i].some(c => String(c||'').includes('Denomination'))) {
      headerIdx = i;
      break;
    }
  }
  if (headerIdx === -1) headerIdx = 1; // fallback

  const COL = {
    region:    0,
    ds:        1,
    pn:        2,
    date:      3,
    pa:        4,
    pv:        5,
    na:        6,
    pr:        7,
    ppe:       8,
    fp:        9,
    np:        10,
    greffe:    11,
    regions:   12,
  };

  const records = [];
  let rowId = 1;

  for (let i = headerIdx + 1; i < rawRows.length; i++) {
    const row = rawRows[i];
    if (!row) continue;

    const ds = cleanStr(row[COL.ds]);
    if (!ds) continue; // ligne vide ou étiquette

    // Ignorer lignes-étiquettes d'années (ex: "2021" dans colonne région)
    const regionRaw = String(row[COL.region] || '').trim();
    if (/^\d{4}$/.test(regionRaw) && !ds) continue;

    const ppeBool = isPPE(row[COL.ppe]);
    const dateObj = parseDate(row[COL.date]);

    let pa = parseNum(row[COL.pa]);
    let pv = parseNum(row[COL.pv]);
    // Valeurs > 100 = erreur de saisie
    if (pa !== null && pa > 100) pa = null;
    if (pv !== null && pv > 100) pv = null;
    if (pa !== null && pa < 0)   pa = null;
    if (pv !== null && pv < 0)   pv = null;

    let fp = cleanStr(row[COL.fp]);
    if (fp && ['0','1'].includes(fp)) fp = null;

    const nat = harmonize(cleanStr(row[COL.na]), 'upper');
    const pays = harmonize(cleanStr(row[COL.pr]), 'upper');
    const reg = cleanStr(regionRaw) && !/^\d{4}$/.test(regionRaw)
      ? regionRaw.charAt(0).toUpperCase() + regionRaw.slice(1)
      : null;

    records.push({
      id: rowId++,
      rs: reg,
      ds: ds,
      pn: cleanStr(row[COL.pn]),
      da: fmtDate(dateObj),
      an: dateObj ? dateObj.getFullYear() : null,
      pa: pa !== null ? Math.round(pa * 100) / 100 : null,
      pv: pv !== null ? Math.round(pv * 100) / 100 : null,
      na: nat,
      pr: pays,
      pp: ppeBool,
      fp: fp,
      np: cleanStr(row[COL.np]),
      gr: cleanStr(row[COL.greffe]),
    });
  }

  return records;
}

/* ── Chargement principal ── */
function loadProgress(pct, msg) {
  document.getElementById('ld-bar').style.width = pct + '%';
  document.getElementById('ld-msg').textContent = msg;
}

function showLoadError(msg) {
  document.getElementById('ld-err').textContent = msg;
  document.getElementById('ld-err').style.display = 'block';
  document.getElementById('ld-msg').textContent = 'Erreur de chargement';
}

async function loadExcel() {
  try {
    loadProgress(10, 'Connexion au fichier Excel...');

    const response = await fetch(EXCEL_PATH);
    if (!response.ok) {
      throw new Error(`Impossible de lire ${EXCEL_PATH} (${response.status}). Assurez-vous d'ouvrir via un serveur web (pas en double-cliquant).`);
    }

    loadProgress(35, 'Téléchargement du fichier...');
    const arrayBuffer = await response.arrayBuffer();

    loadProgress(60, 'Lecture du fichier Excel...');
    const workbook = XLSX.read(arrayBuffer, { type: 'array', cellDates: false });

    loadProgress(75, 'Traitement des données...');
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];
    const records = processSheet(sheet);

    if (records.length === 0) {
      throw new Error('Aucune donnée trouvée dans le fichier Excel.');
    }

    loadProgress(95, `${records.length} bénéficiaires chargés...`);

    window.DB = records;
    window.EXCEL_FILE = EXCEL_PATH;
    window.LOAD_TIME  = new Date().toLocaleString('fr-FR');

    loadProgress(100, 'Prêt !');

    // Mettre à jour l'info fichier dans la sidebar
    document.getElementById('file-info-txt').textContent =
      `${records.length} bénéficiaires · ${[...new Set(records.map(r=>r.ds).filter(Boolean))].length} entreprises · chargé le ${window.LOAD_TIME}`;

    setTimeout(() => {
      document.getElementById('ld').style.display = 'none';
      initApp();
    }, 300);

  } catch (err) {
    console.error('Erreur chargement Excel:', err);
    showLoadError(err.message + '\n\nConseils : ouvrez ce dossier avec Live Server (VS Code), Python http.server, ou tout serveur web local.');
  }
}

/* ── Rechargement à la demande ── */
async function reloadExcel() {
  document.getElementById('ld').style.display = 'flex';
  document.getElementById('ld-err').style.display = 'none';
  await loadExcel();
}

/* ── Lancement ── */
window.addEventListener('DOMContentLoaded', loadExcel);
