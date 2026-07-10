/* =============================================================
   OpenRBE v3 — app.js
   Application principale (appelée après chargement Excel)
============================================================= */

const COORDS = {
  "Dakar":       [14.693,-17.447], "Thiès":       [14.788,-16.924],
  "Diourbel":    [14.655,-16.232], "Fatick":       [14.339,-16.411],
  "Kaolack":     [14.152,-16.073], "Kédougou":     [12.560,-12.186],
  "Mbour":       [14.408,-16.965], "Tambacounda":  [13.771,-13.667],
  "Ziguinchor":  [12.565,-16.272], "Louga":        [15.617,-16.224],
  "Saint-Louis": [16.028,-16.499], "Matam":        [15.658,-13.263],
  "Kolda":       [12.886,-14.944], "Sédhiou":      [12.708,-15.557],
  "Kaffrine":    [14.106,-15.551]
};
const CL  = { g:'#008C45', gd:'#005A2E', y:'#F4C300', yd:'#B89300', r:'#D62D20', b:'#005A8E' };
const NR  = '<span class="nr">—</span>';
const v   = x => (!x && x !== 0) ? NR : x;
const vp  = x => (!x && x !== 0) ? NR : x + '%';
const fmt = n => Number(n).toLocaleString('fr-FR');

let FD = [], charts = {}, leafMap = null;
let nNodes = [], nLinks = [], nZoom = null, nSvg = null;
let dbFiltered = [], dbPage = 1, dbPageSz = 50, dbQ = '';

/* ════════════════════════════════════════
   INIT — appelée par loader.js
════════════════════════════════════════ */
function initApp() {
  FD = [...window.DB];
  dbFiltered = [...window.DB];
  populateFilters();
  applyFilters();
  buildNet();
  setupSearch();
}

/* ── NAV ── */
document.querySelectorAll('.nav-bar a').forEach(a => {
  a.addEventListener('click', e => {
    e.preventDefault();
    document.querySelectorAll('.nav-bar a').forEach(x => x.classList.remove('active'));
    document.querySelectorAll('.page').forEach(x => x.classList.remove('active'));
    a.classList.add('active');
    const pg = a.dataset.page;
    document.getElementById('page-' + pg).classList.add('active');
    if (pg === 'map'      && !leafMap) initMap();
    if (pg === 'network')  buildNet();
    if (pg === 'ppe')      renderPPE();
    if (pg === 'database') renderDB();
  });
});

/* ════════════════════════════════════════
   FILTRES
════════════════════════════════════════ */
function populateFilters() {
  const DB = window.DB;
  const add = (id, arr, multi) => {
    const el = document.getElementById(id);
    if (multi) el.innerHTML = '';
    arr.forEach(x => {
      const o = document.createElement('option');
      o.value = x; o.textContent = x; el.appendChild(o);
    });
  };
  add('fr', [...new Set(DB.map(r => r.rs).filter(Boolean))].sort(), true);
  add('fn', [...new Set(DB.map(r => r.na).filter(Boolean))].sort(), true);
  add('fp', [...new Set(DB.map(r => r.pr).filter(Boolean))].sort(), true);
  const gEl = document.getElementById('fg');
  gEl.innerHTML = '<option value="">Tous</option>';
  [...new Set(DB.map(r => r.gr).filter(Boolean))].sort().forEach(g => {
    const o = document.createElement('option'); o.value = g; o.textContent = g; gEl.appendChild(o);
  });
}

function getSelVals(id) {
  return [...document.getElementById(id).selectedOptions].map(o => o.value).filter(Boolean);
}

function applyFilters() {
  const rs = getSelVals('fr'), na = getSelVals('fn'), pr = getSelVals('fp');
  const gr = document.getElementById('fg').value;
  const pp = document.getElementById('fppe').checked;
  const mn = +document.getElementById('fpmin').value;
  const mx = +document.getElementById('fpmax').value;

  FD = window.DB.filter(r => {
    if (rs.length && !rs.includes(r.rs)) return false;
    if (na.length && !na.includes(r.na)) return false;
    if (pr.length && !pr.includes(r.pr)) return false;
    if (gr && r.gr !== gr) return false;
    if (pp && !r.pp) return false;
    if (r.pa !== null && (r.pa < mn || r.pa > mx)) return false;
    return true;
  });

  document.getElementById('scn').textContent = fmt(FD.length);
  document.getElementById('scp').textContent = Math.round(100 * FD.length / window.DB.length) + '% du total';
  renderAll();
}

['fr','fn','fp','fg'].forEach(id =>
  document.getElementById(id).addEventListener('change', applyFilters)
);
document.getElementById('fppe').addEventListener('change', applyFilters);
[['fpmin','lpmin'],['fpmax','lpmax']].forEach(([id, l]) => {
  document.getElementById(id).addEventListener('input', function() {
    document.getElementById(l).textContent = this.value + '%';
    applyFilters();
  });
});

function resetFilters() {
  ['fr','fn','fp'].forEach(id => [...document.getElementById(id).options].forEach(o => o.selected = false));
  document.getElementById('fg').value = '';
  document.getElementById('fppe').checked = false;
  document.getElementById('fpmin').value = 0; document.getElementById('lpmin').textContent = '0%';
  document.getElementById('fpmax').value = 100; document.getElementById('lpmax').textContent = '100%';
  applyFilters();
}

/* ════════════════════════════════════════
   ANALYTICS
════════════════════════════════════════ */
function getStats(d) {
  const co  = [...new Set(d.map(r => r.ds).filter(Boolean))];
  const pp  = d.filter(r => r.pp);
  const na  = [...new Set(d.map(r => r.na).filter(Boolean))];
  const pr  = [...new Set(d.map(r => r.pr).filter(Boolean))];
  const avg = co.length ? (d.length / co.length).toFixed(1) : '—';
  return { co, pp, na, pr, avg, total: d.length };
}

function getCompanyStructure(d) {
  const m = {};
  d.forEach(r => {
    if (!r.ds) return;
    if (!m[r.ds]) m[r.ds] = { ds: r.ds, rs: r.rs, gr: r.gr, n: 0, pcts: [], ppe: 0 };
    m[r.ds].n++;
    if (r.pa !== null) m[r.ds].pcts.push(r.pa);
    if (r.pp) m[r.ds].ppe++;
  });
  return Object.values(m).map(c => {
    const avg = c.pcts.length ? +(c.pcts.reduce((a,b) => a+b, 0) / c.pcts.length).toFixed(1) : null;
    return { ...c, avg };
  }).sort((a,b) => b.n - a.n);
}

function getRegionStats(d) {
  const m = {};
  d.forEach(r => {
    if (!r.rs) return;
    if (!m[r.rs]) m[r.rs] = { region: r.rs, nb: 0, cos: new Set(), np: 0 };
    m[r.rs].nb++; m[r.rs].cos.add(r.ds); if (r.pp) m[r.rs].np++;
  });
  return Object.values(m).map(r => ({ ...r, ne: r.cos.size })).sort((a,b) => b.nb - a.nb);
}

/* ════════════════════════════════════════
   KPI
════════════════════════════════════════ */
function renderKPI() {
  const s = getStats(FD);
  document.getElementById('k-co').textContent = fmt(s.co.length);
  document.getElementById('k-be').textContent = fmt(s.total);
  document.getElementById('k-av').textContent = s.avg;
  document.getElementById('k-pp').textContent = s.pp.length;
  document.getElementById('k-na').textContent = s.na.length;
  document.getElementById('k-pa').textContent = s.pr.length;
}

/* ════════════════════════════════════════
   CHARTS
════════════════════════════════════════ */
const dc = id => { if (charts[id]) { charts[id].destroy(); delete charts[id]; } };

function renderNat() {
  dc('nat');
  const cnt = {}; FD.forEach(r => { if (r.na) cnt[r.na] = (cnt[r.na]||0)+1; });
  const s = Object.entries(cnt).sort((a,b) => b[1]-a[1]).slice(0,15);
  charts.nat = new Chart(document.getElementById('ch-nat').getContext('2d'), {
    type: 'bar',
    data: { labels: s.map(x => x[0]), datasets: [{ data: s.map(x => x[1]), backgroundColor: CL.g, borderColor: CL.gd, borderWidth: .5, hoverBackgroundColor: CL.yd }] },
    options: { indexAxis: 'y', responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: c => ' ' + c.parsed.x + ' bén.' } } }, scales: { x: { grid: { color: '#f0f0f0' } }, y: { ticks: { font: { size: 10 } } } } }
  });
}

function renderPiePPE() {
  dc('ppe-ch');
  const pp = FD.filter(r => r.pp).length;
  charts['ppe-ch'] = new Chart(document.getElementById('ch-ppe').getContext('2d'), {
    type: 'doughnut',
    data: { labels: ['PPE', 'Non PPE'], datasets: [{ data: [pp, FD.length - pp], backgroundColor: [CL.r, CL.g], borderWidth: 2, borderColor: '#fff' }] },
    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' }, tooltip: { callbacks: { label: c => c.label + ': ' + c.parsed + ' (' + Math.round(100*c.parsed/FD.length) + '%)' } } } }
  });
}

function renderReg() {
  dc('reg');
  const d = getRegionStats(FD);
  charts.reg = new Chart(document.getElementById('ch-reg').getContext('2d'), {
    type: 'bar',
    data: { labels: d.map(r => r.region), datasets: [{ label: 'Bénéficiaires', data: d.map(r => r.nb), backgroundColor: CL.g, borderWidth: .5 }, { label: 'Entreprises', data: d.map(r => r.ne), backgroundColor: CL.y, borderWidth: .5 }] },
    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'top', labels: { font: { size: 11 } } } }, scales: { x: { ticks: { font: { size: 10 } } }, y: { grid: { color: '#f0f0f0' } } } }
  });
}

function renderPct() {
  dc('pct');
  const bins = Array(20).fill(0);
  FD.forEach(r => { if (r.pa !== null) bins[Math.min(19, Math.floor(r.pa / 5))]++; });
  charts.pct = new Chart(document.getElementById('ch-pct').getContext('2d'), {
    type: 'bar',
    data: { labels: bins.map((_,i) => i*5+'%'), datasets: [{ data: bins, backgroundColor: CL.y, borderColor: CL.yd, borderWidth: .5 }] },
    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { x: { ticks: { font: { size: 9 }, maxRotation: 60 } }, y: { grid: { color: '#f0f0f0' } } } }
  });
}

/* ── Top table ── */
function getTopData() {
  return getCompanyStructure(FD).slice(0,30).map(c => ({
    'Entreprise': c.ds, 'Région': c.rs||'', 'Greffe': c.gr||'',
    'Bénéficiaires': c.n, 'Part. moy.': c.avg !== null ? c.avg+'%' : '', 'PPE': c.ppe
  }));
}

function renderTopTable() {
  const tb = document.querySelector('#tbl-top tbody'); tb.innerHTML = '';
  getCompanyStructure(FD).slice(0,30).forEach(c => {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td><strong>${c.ds}</strong></td><td>${c.rs?'<span class="bg">'+c.rs+'</span>':NR}</td><td>${c.gr?'<span class="bgr">'+c.gr+'</span>':NR}</td><td><strong>${c.n}</strong></td><td>${c.avg!==null?c.avg+'%':NR}</td><td>${c.ppe>0?'<span class="br">'+c.ppe+' PPE</span>':'0'}</td>`;
    tb.appendChild(tr);
  });
}

/* ════════════════════════════════════════
   BASE COMPLÈTE
════════════════════════════════════════ */
function getDBData() {
  return dbFiltered.map((r,i) => ({
    '#': i+1, 'Entreprise': r.ds||'', 'Bénéficiaire': r.pn||'',
    'Région': r.rs||'', 'Nationalité': r.na||'', 'Pays résidence': r.pr||'',
    '% Action': r.pa??'', '% Voix': r.pv??'',
    'PPE': r.pp?'Oui':'Non', 'Fonction PPE': r.fp||'', 'Nom PPE': r.np||'',
    'Greffe': r.gr||'', 'Date acquisition': r.da||'', 'Année': r.an||''
  }));
}

function renderDB() {
  const q = dbQ.toLowerCase().trim();
  dbFiltered = FD.filter(r => {
    if (!q) return true;
    return [r.ds,r.pn,r.na,r.pr,r.rs,r.gr,r.fp,r.np].some(x => x && x.toLowerCase().includes(q));
  });

  const total = dbFiltered.length;
  const psz   = dbPageSz >= 9999 ? total : dbPageSz;
  const pages = Math.max(1, Math.ceil(total / psz));
  if (dbPage > pages) dbPage = 1;
  const start = (dbPage - 1) * psz;
  const end   = Math.min(start + psz, total);

  document.getElementById('db-count-lbl').textContent =
    fmt(total) + ' enregistrement' + (total > 1 ? 's' : '');
  document.getElementById('db-info').textContent = q
    ? `Filtre "${dbQ}" : ${fmt(total)} résultat(s) sur ${fmt(FD.length)}`
    : `${fmt(FD.length)} bénéficiaires dans la sélection — ${fmt(window.DB.length)} au total`;

  const tb = document.getElementById('db-tbody'); tb.innerHTML = '';
  dbFiltered.slice(start, end).forEach((r, i) => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td style="color:var(--gray);font-size:.74rem;text-align:right">${start+i+1}</td>
      <td><strong>${r.ds||'—'}</strong></td>
      <td>${r.pn||NR}</td>
      <td>${r.rs?'<span class="bg">'+r.rs+'</span>':NR}</td>
      <td>${v(r.na)}</td><td>${v(r.pr)}</td>
      <td style="text-align:center">${vp(r.pa)}</td>
      <td style="text-align:center">${vp(r.pv)}</td>
      <td style="text-align:center">${r.pp?'<span class="br">PPE</span>':''}</td>
      <td>${v(r.fp)}</td><td>${v(r.np)}</td>
      <td>${r.gr?'<span class="bgr">'+r.gr+'</span>':NR}</td>
      <td style="white-space:nowrap;font-size:.79rem">${v(r.da)}</td>
      <td style="text-align:center">${v(r.an)}</td>`;
    tb.appendChild(tr);
  });

  // Pagination
  document.getElementById('pg-info').textContent =
    `Lignes ${fmt(start+1)}–${fmt(end)} sur ${fmt(total)}`;
  document.getElementById('pg-prev').disabled = dbPage <= 1;
  document.getElementById('pg-next').disabled = dbPage >= pages;

  const pgDiv = document.getElementById('pg-pages'); pgDiv.innerHTML = '';
  let s2 = Math.max(1, dbPage-3), e2 = Math.min(pages, s2+6);
  if (e2-s2 < 6) s2 = Math.max(1, e2-6);
  for (let p = s2; p <= e2; p++) {
    const b = document.createElement('button');
    b.className = 'pg-btn' + (p === dbPage ? ' on' : '');
    b.textContent = p;
    const pp = p;
    b.onclick = () => { dbPage = pp; renderDB(); };
    pgDiv.appendChild(b);
  }
}

function dbPageNav(dir) { dbPage += dir; renderDB(); }
function dbPageSize()   { dbPageSz = +document.getElementById('pg-sz').value; dbPage = 1; renderDB(); }

let dbTimer;
document.getElementById('db-search').addEventListener('input', function() {
  clearTimeout(dbTimer);
  dbQ = this.value;
  dbTimer = setTimeout(() => { dbPage = 1; renderDB(); }, 200);
});

/* ════════════════════════════════════════
   RECHERCHE ENTREPRISE
════════════════════════════════════════ */
function setupSearch() {
  const allCo = [...new Set(window.DB.map(r => r.ds).filter(Boolean))].sort();
  const si = document.getElementById('si');
  const sdd = document.getElementById('sdd');

  si.addEventListener('input', function() {
    const q = this.value.trim().toLowerCase();
    sdd.innerHTML = '';
    if (!q) { sdd.style.display = 'none'; return; }
    const matches = allCo.filter(c => c.toLowerCase().includes(q)).slice(0, 35);
    if (!matches.length) { sdd.style.display = 'none'; return; }
    matches.forEach(c => {
      const d = document.createElement('div'); d.className = 'ddi';
      const i = c.toLowerCase().indexOf(q);
      d.innerHTML = c.substring(0,i) + '<mark>' + c.substring(i,i+q.length) + '</mark>' + c.substring(i+q.length);
      d.addEventListener('click', () => { si.value = c; sdd.style.display = 'none'; renderCompanyCard(c); });
      sdd.appendChild(d);
    });
    sdd.style.display = 'block';
  });
  document.addEventListener('click', e => { if (!e.target.closest('.sw')) sdd.style.display = 'none'; });
}

function renderCC(nm) { return renderCompanyCard(nm); }
function renderCompanyCard(nm) {
  const rows   = window.DB.filter(r => r.ds === nm);
  if (!rows.length) return;
  const nats   = [...new Set(rows.map(r => r.na).filter(Boolean))].sort();
  const pays   = [...new Set(rows.map(r => r.pr).filter(Boolean))].sort();
  const ppes   = rows.filter(r => r.pp);
  const pcts   = rows.map(r => r.pa).filter(x => x !== null);
  const avg    = pcts.length ? (pcts.reduce((a,b) => a+b, 0) / pcts.length).toFixed(1) : null;
  const med    = pcts.length ? pcts.sort((a,b) => a-b)[Math.floor(pcts.length/2)] : null;
  const dates  = rows.map(r => r.da).filter(Boolean).sort();
  const annees = [...new Set(rows.map(r => r.an).filter(Boolean))].sort();
  const sfx    = nm.replace(/[^a-zA-Z0-9]/g,'_').substring(0,30);

  document.getElementById('ccw').innerHTML = `
  <div class="cc">
    <div class="cch">
      <div class="cci"><i class="fas fa-building"></i></div>
      <div>
        <div class="ccn">${nm}</div>
        <div style="display:flex;gap:5px;flex-wrap:wrap">
          ${rows[0].rs?'<span class="bg">'+rows[0].rs+'</span>':''}
          ${rows[0].gr?'<span class="bgr">Greffe : '+rows[0].gr+'</span>':''}
        </div>
      </div>
    </div>
    <div class="ccs">
      <div><span class="csv">${rows.length}</span><span class="csl">Bénéficiaire(s)</span></div>
      <div><span class="csv ${ppes.length>0?'red':''}">${ppes.length}</span><span class="csl">PPE</span></div>
      <div><span class="csv">${avg!==null?avg+'%':'—'}</span><span class="csl">Part. moyenne</span></div>
      <div><span class="csv">${med!==null?med+'%':'—'}</span><span class="csl">Part. médiane</span></div>
    </div>
    <div class="ccd">
      <div><div class="cdl"><i class="fas fa-flag"></i> Nationalité(s)</div>${nats.length?nats.join(' • '):NR}</div>
      <div><div class="cdl"><i class="fas fa-globe"></i> Pays de résidence</div>${pays.length?pays.join(' • '):NR}</div>
      <div><div class="cdl"><i class="fas fa-calendar"></i> 1ère déclaration</div>${dates[0]||NR}</div>
      <div><div class="cdl"><i class="fas fa-clock"></i> Dernière mise à jour</div>${dates[dates.length-1]||NR}</div>
      <div><div class="cdl"><i class="fas fa-calendar-alt"></i> Année(s)</div>${annees.length?annees.join(', '):NR}</div>
      ${ppes.length?'<div><div class="cdl" style="color:var(--r)"><i class="fas fa-user-shield"></i> PPE identifiés</div><div style="color:var(--r);font-weight:600">'+ppes.map(p=>p.pn).join(' • ')+'</div></div>':''}
    </div>
  </div>
  <div class="card">
    <div class="ct"><i class="fas fa-users"></i> Bénéficiaires effectifs</div>
    <div class="eb">
      <button class="be bxl" onclick="exportXLSX(getBensData('${nm.replace(/'/g,"\\'")}'),'bens_${sfx}')"><i class="fas fa-file-excel"></i> Excel</button>
      <button class="be bcsv" onclick="exportCSV(getBensData('${nm.replace(/'/g,"\\'")}'),'bens_${sfx}')"><i class="fas fa-file-csv"></i> CSV</button>
    </div>
    <div class="tw"><table><thead><tr>
      <th>Bénéficiaire</th><th>Nationalité</th><th>Pays résidence</th>
      <th>% Action</th><th>% Voix</th><th>PPE</th><th>Fonction PPE</th><th>Nom PPE</th><th>Date acq.</th>
    </tr></thead><tbody>
    ${rows.map(r=>`<tr>
      <td><strong>${r.pn||'—'}</strong></td><td>${v(r.na)}</td><td>${v(r.pr)}</td>
      <td style="text-align:center">${vp(r.pa)}</td><td style="text-align:center">${vp(r.pv)}</td>
      <td style="text-align:center">${r.pp?'<span class="br">PPE</span>':''}</td>
      <td>${v(r.fp)}</td><td>${v(r.np)}</td>
      <td style="white-space:nowrap">${v(r.da)}</td>
    </tr>`).join('')}
    </tbody></table></div>
  </div>`;
}

function getBensData(nm) {
  return window.DB.filter(r => r.ds === nm).map(r => ({
    'Bénéficiaire': r.pn||'', 'Nationalité': r.na||'', 'Pays résidence': r.pr||'',
    '% Action': r.pa??'', '% Voix': r.pv??'',
    'PPE': r.pp?'Oui':'Non', 'Fonction PPE': r.fp||'', 'Nom PPE': r.np||'', 'Date': r.da||''
  }));
}

/* ════════════════════════════════════════
   PPE
════════════════════════════════════════ */
function getPPEData() {
  return FD.filter(r => r.pp).map(r => ({
    'Bénéficiaire': r.pn, 'Entreprise': r.ds, 'Région': r.rs||'',
    'Nationalité': r.na||'', 'Pays résidence': r.pr||'',
    '% Action': r.pa??'', '% Voix': r.pv??'',
    'Fonction PPE': r.fp||'', 'Nom PPE': r.np||''
  }));
}

function renderPPE() {
  const ppes = FD.filter(r => r.pp);
  const na   = [...new Set(ppes.map(r => r.na).filter(Boolean))];
  const pr   = [...new Set(ppes.map(r => r.pr).filter(Boolean))];
  const pcts = ppes.map(r => r.pa).filter(x => x !== null);
  const avg  = pcts.length ? (pcts.reduce((a,b) => a+b, 0) / pcts.length).toFixed(1) : '—';
  const co   = [...new Set(ppes.map(r => r.ds).filter(Boolean))];

  document.getElementById('ppe-kpis').innerHTML = [
    { ico:'fa-user-shield', val:ppes.length, lbl:'Total PPE',     col:'var(--r)'  },
    { ico:'fa-building',    val:co.length,   lbl:'Entreprises',   col:'var(--yd)' },
    { ico:'fa-flag',        val:na.length,   lbl:'Nationalités',  col:'var(--g)'  },
    { ico:'fa-globe',       val:pr.length,   lbl:'Pays résidence',col:'var(--b)'  },
    { ico:'fa-percent',     val:avg+'%',     lbl:'Part. moy.',    col:'var(--gd)' },
  ].map(k => `<div class="kpi" style="border-top-color:${k.col}"><div class="ki" style="color:${k.col}"><i class="fas ${k.ico}"></i></div><div><div class="kv">${k.val}</div><div class="kl">${k.lbl}</div></div></div>`).join('');

  dc('ppn'); dc('ppr');
  const nc = {}, rc = {};
  ppes.forEach(r => { if (r.na) nc[r.na]=(nc[r.na]||0)+1; if (r.rs) rc[r.rs]=(rc[r.rs]||0)+1; });
  const ns = Object.entries(nc).sort((a,b) => b[1]-a[1]);
  const rs2= Object.entries(rc).sort((a,b) => b[1]-a[1]);
  charts.ppn = new Chart(document.getElementById('ch-pn').getContext('2d'), { type:'bar', data:{ labels:ns.map(x=>x[0]), datasets:[{ data:ns.map(x=>x[1]), backgroundColor:CL.r, borderWidth:.5 }] }, options:{ responsive:true, maintainAspectRatio:false, plugins:{legend:{display:false}}, scales:{y:{grid:{color:'#f0f0f0'}}} } });
  charts.ppr = new Chart(document.getElementById('ch-pr').getContext('2d'), { type:'bar', data:{ labels:rs2.map(x=>x[0]), datasets:[{ data:rs2.map(x=>x[1]), backgroundColor:CL.y, borderColor:CL.yd, borderWidth:.5 }] }, options:{ responsive:true, maintainAspectRatio:false, plugins:{legend:{display:false}}, scales:{y:{grid:{color:'#f0f0f0'}}} } });

  const tb = document.querySelector('#tbl-ppe tbody');
  tb.innerHTML = ppes.length
    ? ppes.map(r=>`<tr><td><strong style="color:var(--r)">${r.pn||NR}</strong></td><td>${r.ds||NR}</td><td>${r.rs?'<span class="bg">'+r.rs+'</span>':NR}</td><td>${v(r.na)}</td><td>${v(r.pr)}</td><td style="text-align:center">${vp(r.pa)}</td><td style="text-align:center">${vp(r.pv)}</td><td>${v(r.fp)}</td><td>${v(r.np)}</td></tr>`).join('')
    : '<tr><td colspan="9" style="text-align:center;color:var(--gray);padding:18px">Aucun PPE dans la sélection.</td></tr>';
}

/* ════════════════════════════════════════
   CARTE LEAFLET
════════════════════════════════════════ */
function initMap() {
  leafMap = L.map('map', { center:[14.4,-14.4], zoom:7, minZoom:6, maxZoom:10, maxBounds:[[12,-17.6],[16.7,-11.3]], maxBoundsViscosity:1.0 });
  L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', { attribution:'© OpenStreetMap | © CartoDB | ITIE Sénégal', noWrap:true }).addTo(leafMap);
  updateMap();
  document.querySelectorAll('input[name="mm"]').forEach(r => r.addEventListener('change', updateMap));
}

function updateMap() {
  if (!leafMap) return;
  leafMap.eachLayer(l => { if (l instanceof L.CircleMarker) leafMap.removeLayer(l); });
  const metric = document.querySelector('input[name="mm"]:checked').value;
  const rs = getRegionStats(FD);
  const fk = { nb:'nb', ne:'ne', np:'np' }[metric];
  const maxV = Math.max(...rs.map(s => s[fk]||0), 1);
  const label = { nb:'Bénéficiaires', ne:'Entreprises', np:'PPE' }[metric];

  rs.forEach(s => {
    const c = COORDS[s.region]; if (!c) return;
    const val = s[fk]||0, rad = 10 + (val/maxV)*45;
    L.circleMarker(c, { radius:rad, fillColor:val?CL.g:'#ccc', fillOpacity:.2+.65*(val/maxV), color:CL.gd, weight:1.5 })
     .bindPopup(`<div style="font-family:DM Sans,sans-serif;min-width:190px"><div style="font-size:15px;font-weight:700;color:#008C45;border-bottom:2px solid #008C45;padding-bottom:5px;margin-bottom:8px">${s.region}</div><table style="width:100%;font-size:13px"><tr><td>Entreprises</td><td style="text-align:right;font-weight:600">${s.ne}</td></tr><tr><td>Bénéficiaires</td><td style="text-align:right;font-weight:600">${s.nb}</td></tr><tr><td style="color:#D62D20;font-weight:600">PPE</td><td style="text-align:right;color:#D62D20;font-weight:700">${s.np}</td></tr></table></div>`)
     .bindTooltip(`${s.region} — ${label} : ${val}`, { sticky:true }).addTo(leafMap);
  });

  const tb = document.querySelector('#tbl-reg tbody');
  tb.innerHTML = rs.map(s=>`<tr><td><span class="bg">${s.region}</span></td><td>${s.ne}</td><td><strong>${s.nb}</strong></td><td style="${s.np>0?'color:var(--r);font-weight:700':''}">${s.np}</td></tr>`).join('');
}

/* ════════════════════════════════════════
   RÉSEAU D3
════════════════════════════════════════ */
function buildNet() {
  if (!window.DB) return;
  const maxC = +document.getElementById('nmx').value;
  const cnt = {}; FD.forEach(r => { if (r.ds) cnt[r.ds] = (cnt[r.ds]||0)+1; });
  const top = Object.entries(cnt).sort((a,b) => b[1]-a[1]).slice(0,maxC).map(e => e[0]);
  const sub = FD.filter(r => top.includes(r.ds));
  const nm = {}; nNodes = []; nLinks = [];

  top.forEach((c,i) => { const id='C'+i; nm['C|'+c]=id; nNodes.push({id, label:c.length>28?c.substring(0,28)+'…':c, group:'co', full:c}); });
  [...new Set(sub.map(r=>r.pn).filter(Boolean))].forEach((b,i) => { const id='B'+i; nm['B|'+b]=id; nNodes.push({id, label:b.length>24?b.substring(0,24)+'…':b, group:'be', full:b}); });
  sub.forEach(r => { if (!r.ds||!r.pn) return; const s=nm['C|'+r.ds], t=nm['B|'+r.pn]; if(s&&t) nLinks.push({source:s, target:t, pct:r.pa}); });

  const sc=document.getElementById('ns-co'), sb=document.getElementById('ns-be');
  sc.innerHTML='<option value="">— Toutes —</option>';
  sb.innerHTML='<option value="">— Tous —</option>';
  top.forEach(c => { const o=document.createElement('option'); o.value=c; o.textContent=c; sc.appendChild(o); });
  [...new Set(sub.map(r=>r.pn).filter(Boolean))].sort().forEach(b => { const o=document.createElement('option'); o.value=b; o.textContent=b; sb.appendChild(o); });
  drawNet();
}

function drawNet() {
  d3.select('#nsvg').selectAll('*').remove();
  document.getElementById('nib').style.display = 'none';
  const wrap=document.getElementById('nwrap'), W=wrap.clientWidth||900, H=wrap.clientHeight||500;
  nSvg = d3.select('#nsvg').attr('viewBox',`0 0 ${W} ${H}`);
  const nG = nSvg.append('g');
  nZoom = d3.zoom().scaleExtent([.15,6]).on('zoom', e => nG.attr('transform', e.transform));
  nSvg.call(nZoom);

  const sim = d3.forceSimulation(nNodes)
    .force('link',   d3.forceLink(nLinks).id(d=>d.id).distance(90).strength(.5))
    .force('charge', d3.forceManyBody().strength(-130))
    .force('center', d3.forceCenter(W/2,H/2))
    .force('col',    d3.forceCollide(22));

  const link = nG.append('g').selectAll('line').data(nLinks).join('line').attr('stroke','#ddd').attr('stroke-width',1);
  const node = nG.append('g').selectAll('g').data(nNodes).join('g').attr('cursor','pointer')
    .call(d3.drag()
      .on('start',(e,d)=>{ if(!e.active) sim.alphaTarget(.3).restart(); d.fx=d.x; d.fy=d.y; })
      .on('drag', (e,d)=>{ d.fx=e.x; d.fy=e.y; })
      .on('end',  (e,d)=>{ if(!e.active) sim.alphaTarget(0); d.fx=null; d.fy=null; })
    )
    .on('click',(e,d)=>{ e.stopPropagation(); zoomNode(d); });

  node.append('circle').attr('r',d=>d.group==='co'?15:9).attr('fill',d=>d.group==='co'?CL.g:CL.y).attr('stroke',d=>d.group==='co'?CL.gd:CL.yd).attr('stroke-width',1.5);
  node.append('text').text(d=>d.label).attr('x',0).attr('y',d=>d.group==='co'?-19:-13).attr('text-anchor','middle').attr('font-size',d=>d.group==='co'?'10px':'9px').attr('fill','#1A1A1A').attr('font-family','DM Sans,sans-serif').attr('font-weight',d=>d.group==='co'?'600':'400');
  sim.on('tick',()=>{ link.attr('x1',d=>d.source.x).attr('y1',d=>d.source.y).attr('x2',d=>d.target.x).attr('y2',d=>d.target.y); node.attr('transform',d=>`translate(${d.x},${d.y})`); });
  nSvg.on('click',()=>document.getElementById('nib').style.display='none');
}

function zoomNode(nd) {
  if (!nd || !nSvg || !nZoom) return;
  const el=document.getElementById('nsvg'), W=el.clientWidth||900, H=el.clientHeight||500;
  const sc=2.4, tx=W/2-sc*(nd.x||W/2), ty=H/2-sc*(nd.y||H/2);
  nSvg.transition().duration(700).call(nZoom.transform, d3.zoomIdentity.translate(tx,ty).scale(sc));
  const lk = nLinks.filter(l=>(l.source.id||l.source)===nd.id||(l.target.id||l.target)===nd.id);
  const isCo = nd.group==='co';
  const info = document.getElementById('nib'); info.style.display='flex';
  info.innerHTML=`<div class="niico" style="background:${isCo?CL.g:CL.yd}"><i class="fas ${isCo?'fa-building':'fa-user'}"></i></div><div><strong style="font-size:14px;display:block">${nd.full}</strong><span style="font-size:12px;color:var(--gray)">${isCo?'Entreprise':'Bénéficiaire'} — ${lk.length} ${isCo?'bénéficiaire(s) relié(s)':'entreprise(s) reliée(s)'}</span></div>`;
}

function focusNode(val, type) {
  if (!val) return;
  const nd = nNodes.find(n => n.full===val && (type==='co'?n.group==='co':n.group==='be'));
  if (!nd) return;
  if (type==='co') document.getElementById('ns-be').value='';
  else document.getElementById('ns-co').value='';
  zoomNode(nd);
}

function expNetPNG() {
  const se=document.getElementById('nsvg'), s=new XMLSerializer().serializeToString(se);
  const c=document.createElement('canvas'); c.width=se.clientWidth||900; c.height=se.clientHeight||500;
  const ctx=c.getContext('2d'); ctx.fillStyle='#FAFCFB'; ctx.fillRect(0,0,c.width,c.height);
  const img=new Image(); img.onload=()=>{ ctx.drawImage(img,0,0); const a=document.createElement('a'); a.download='openrbe_reseau.png'; a.href=c.toDataURL('image/png'); a.click(); };
  img.src='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(s);
}

/* ════════════════════════════════════════
   EXPORTS
════════════════════════════════════════ */
function exportCSV(rows, name) {
  if (!rows.length) return;
  const h = Object.keys(rows[0]);
  const lines = [h.join(';'), ...rows.map(r => h.map(k => {
    const val = r[k]==null?'':String(r[k]);
    return val.includes(';')||val.includes('"') ? '"'+val.replace(/"/g,'""')+'"' : val;
  }).join(';'))];
  const b = new Blob(['\uFEFF'+lines.join('\n')], {type:'text/csv;charset=utf-8'});
  const u = URL.createObjectURL(b), a = document.createElement('a');
  a.href=u; a.download=name+'_'+new Date().toISOString().slice(0,10)+'.csv'; a.click(); URL.revokeObjectURL(u);
}

function exportXLSX(rows, name) { exportCSV(rows, name); }

/* ════════════════════════════════════════
   RENDER ALL
════════════════════════════════════════ */
function renderAll() {
  renderKPI(); renderNat(); renderPiePPE(); renderReg(); renderPct(); renderTopTable();
  if (document.getElementById('page-ppe').classList.contains('active'))      renderPPE();
  if (document.getElementById('page-database').classList.contains('active')) renderDB();
  if (leafMap) updateMap();
}
